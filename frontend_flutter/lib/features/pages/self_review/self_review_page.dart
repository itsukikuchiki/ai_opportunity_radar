import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/self_review_models.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/aurora_ui.dart';
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
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AuroraIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(AppRoutes.me);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  AuroraCard(
                    padding: const EdgeInsets.all(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFF7F3FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    child: Row(
                      children: [
                        const AuroraSoftIconCircle(
                          icon: Icons.spa_rounded,
                          color: AuroraColors.purple,
                          size: 64,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'Why is recovery difficult at night?',
                                  zhHans: '本次专题：为什么一到晚上就很难恢复？',
                                  zhHant: '本次專題：為什麼一到晚上就很難恢復？',
                                  ja: '今回のテーマ：夜になると回復しにくい理由',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: AuroraColors.ink,
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'A slower pass based on recent signals.',
                                  zhHans: '基于最近 7 天的信号，做一次证据驱动的自我回顾。',
                                  zhHant: '基於最近 7 天的信號，做一次證據驅動的自我回顧。',
                                  ja: '最近 7 日のシグナルから、証拠に沿って見直します。',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AuroraColors.muted,
                                      height: 1.45,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  AuroraChip(
                                    label: review == null ||
                                            review.reviewedDays <= 0
                                        ? AppLocaleText.tr(context,
                                            en: 'Current focus',
                                            zhHans: '当前关注',
                                            zhHant: '目前關注',
                                            ja: '今の焦点')
                                        : AppLocaleText.tr(context,
                                            en:
                                                '${review.reviewedDays} active days',
                                            zhHans:
                                                '${review.reviewedDays} 个记录日',
                                            zhHant:
                                                '${review.reviewedDays} 個記錄日',
                                            ja: '${review.reviewedDays} 日分'),
                                  ),
                                  AuroraChip(
                                    label: _preferenceText(
                                      context,
                                      meVm.selectedRepeatArea,
                                    ),
                                    color: AuroraColors.blue,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ..._buildBody(context, vm),
                ],
              ),
            ),
          ),
          const AuroraSafeTopMask(),
        ],
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context, SelfReviewViewModel vm) {
    final review = vm.review;
    switch (vm.loadState) {
      case LoadState.loading:
        return const [
          _ReviewLoadingState(),
        ];
      case LoadState.error:
        return [
          _ReviewMessageState(
            icon: Icons.warning_amber_rounded,
            color: AuroraColors.orange,
            title: AppLocaleText.tr(context,
                en: 'Self review failed to load',
                zhHans: '专题梳理加载失败',
                zhHant: '專題梳理載入失敗',
                ja: 'セルフレビューの読み込みに失敗しました'),
            subtitle: vm.errorMessage,
          ),
        ];
      case LoadState.empty:
        return [
          _ReviewMessageState(
            icon: Icons.psychology_alt_rounded,
            color: AuroraColors.purple,
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
          _RelatedRecordStrip(),
          const SizedBox(height: 18),
          _ReviewSection(
            number: '01',
            title: AppLocaleText.tr(context,
                en: 'Pattern I can see',
                zhHans: '我看到的模式',
                zhHant: '我看到的模式',
                ja: '見えてきたパターン'),
            subtitle: AppLocaleText.tr(context,
                en: 'Early finding based on evidence',
                zhHans: '基于证据的初步发现',
                zhHant: '基於證據的初步發現',
                ja: '証拠にもとづく初期の発見'),
            items: review.repeatedBlockers,
            color: AuroraColors.purple,
          ),
          const SizedBox(height: 18),
          _ReviewSection(
            number: '02',
            title: AppLocaleText.tr(context,
                en: 'A place to reinterpret',
                zhHans: '可以重新理解的地方',
                zhHant: '可以重新理解的地方',
                ja: '捉え直せるところ'),
            subtitle: AppLocaleText.tr(context,
                en: 'A gentler angle',
                zhHans: '新的视角',
                zhHant: '新的視角',
                ja: '新しい見方'),
            items: review.mainDrains,
            color: AuroraColors.orange,
          ),
          const SizedBox(height: 18),
          _ReviewSection(
            number: '03',
            title: AppLocaleText.tr(context,
                en: 'Next small try',
                zhHans: '下一步尝试',
                zhHant: '下一步嘗試',
                ja: '次の小さな試み'),
            subtitle: AppLocaleText.tr(context,
                en: 'Small experiment',
                zhHans: '小步实验',
                zhHant: '小步實驗',
                ja: '小さな実験'),
            items: review.helpingPatterns,
            color: AuroraColors.mint,
          ),
          const SizedBox(height: 18),
          _SelfReviewActionLoopCard(review: review),
          const SizedBox(height: 18),
          AuroraQuoteCard(
            text: review.closingNote,
            icon: Icons.auto_awesome_rounded,
          ),
        ];
      case LoadState.initial:
        return const [SizedBox.shrink()];
    }
  }

  String _preferenceText(BuildContext context, String? value) {
    final label = switch (value) {
      'work_tasks' => AppLocaleText.tr(context,
          en: 'work and tasks', zhHans: '工作与任务', zhHant: '工作與任務', ja: '仕事とタスク'),
      'emotion_stress' => AppLocaleText.tr(context,
          en: 'emotions and stress',
          zhHans: '情绪与压力',
          zhHant: '情緒與壓力',
          ja: '感情とストレス'),
      'relationships' => AppLocaleText.tr(context,
          en: 'relationships', zhHans: '关系与相处', zhHant: '關係與相處', ja: '人間関係'),
      'time_rhythm' => AppLocaleText.tr(context,
          en: 'time and rhythm',
          zhHans: '时间与节奏',
          zhHant: '時間與節奏',
          ja: '時間とリズム'),
      _ => AppLocaleText.tr(context,
          en: 'current focus', zhHans: '当前关注', zhHant: '當前關注', ja: '今の注目'),
    };
    return label;
  }
}

class _ReviewLoadingState extends StatelessWidget {
  const _ReviewLoadingState();

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const AuroraSoftIconCircle(
            icon: Icons.auto_awesome_rounded,
            color: AuroraColors.purple,
            size: 72,
          ),
          const SizedBox(height: 18),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Gathering your signals...',
              zhHans: '正在整理最近的信号...',
              zhHant: '正在整理最近的信號...',
              ja: '最近のシグナルを整理しています...',
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReviewMessageState extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  const _ReviewMessageState({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          AuroraSoftIconCircle(icon: icon, color: color, size: 72),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.5,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RelatedRecordStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.auto_awesome_rounded, '21:43', '今天不想回消息。', AuroraColors.purple),
      (Icons.work_rounded, '19:30', '和朋友晚餐', AuroraColors.orange),
      (Icons.menu_book_rounded, '17:10', '阅读 30 分钟', AuroraColors.mint),
    ];
    return AuroraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocaleText.tr(context,
                    en: 'Related records',
                    zhHans: '相关记录',
                    zhHant: '相關記錄',
                    ja: '関連する記録'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Text(
                AppLocaleText.tr(context,
                    en: 'View all',
                    zhHans: '查看全部',
                    zhHant: '查看全部',
                    ja: 'すべて見る'),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AuroraColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: items
                .map(
                  (item) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: item.$4.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: item.$4.withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        children: [
                          AuroraSoftIconCircle(
                            icon: item.$1,
                            color: item.$4,
                            size: 34,
                            iconSize: 17,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.$2,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium),
                                Text(
                                  item.$3,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: AuroraColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SelfReviewActionLoopCard extends StatelessWidget {
  final SelfReviewModel review;

  const _SelfReviewActionLoopCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final judgement = review.repeatedBlockers.isNotEmpty
        ? review.repeatedBlockers.first
        : AppLocaleText.tr(
            context,
            en: 'The theme is still forming. Keep the evidence light for now.',
            zhHans: '这个专题还在形成中，先把证据轻轻留下。',
            zhHant: '這個專題還在形成中，先把證據輕輕留下。',
            ja: 'このテーマはまだ形になっている途中です。まずは証拠を軽く残します。',
          );
    final action = review.helpingPatterns.isNotEmpty
        ? review.helpingPatterns.first
        : AppLocaleText.tr(
            context,
            en: 'Choose one small adjustment and review whether it saves a little effort.',
            zhHans: '先选一个小调整，再回看它有没有帮你省一点力。',
            zhHant: '先選一個小調整，再回看它有沒有幫你省一點力。',
            ja: '小さな調整を一つ選び、少し楽になったかを後で見ます。',
          );

    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF7F3FF)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.route_rounded,
                color: AuroraColors.purple,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Theme loop',
                    zhHans: '专题闭环',
                    zhHant: '專題閉環',
                    ja: 'テーマの循環',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _LoopStepTile(
            icon: Icons.auto_awesome_rounded,
            color: AuroraColors.purple,
            label: AppLocaleText.tr(
              context,
              en: 'AI judgement',
              zhHans: 'AI 判断',
              zhHant: 'AI 判斷',
              ja: 'AI の判断',
            ),
            body: judgement,
          ),
          const SizedBox(height: 10),
          _LoopStepTile(
            icon: Icons.science_rounded,
            color: AuroraColors.mint,
            label: AppLocaleText.tr(
              context,
              en: 'Small action',
              zhHans: '小行动',
              zhHant: '小行動',
              ja: '小さな行動',
            ),
            body: action,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReviewActionChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Set as weekly try',
                  zhHans: '设为本周尝试',
                  zhHant: '設為本週嘗試',
                  ja: '今週試す',
                ),
                filled: true,
              ),
              _ReviewActionChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Looks right',
                  zhHans: '准',
                  zhHant: '準',
                  ja: '合っている',
                ),
              ),
              _ReviewActionChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Partly',
                  zhHans: '有一部分',
                  zhHant: '有一部分',
                  ja: '一部だけ',
                ),
              ),
              _ReviewActionChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Another angle',
                  zhHans: '换个角度',
                  zhHant: '換個角度',
                  ja: '別の角度',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Next Weekly can use this as a Review & Adjust entry.',
              zhHans: '下一次 Weekly 可以把它作为 Review & Adjust 的入口。',
              zhHant: '下一次 Weekly 可以把它作為 Review & Adjust 的入口。',
              ja: '次の Weekly で Review & Adjust の入口として使えます。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _LoopStepTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String body;

  const _LoopStepTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(
              icon: icon, color: color, size: 32, iconSize: 17),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AuroraColors.ink,
                      height: 1.42,
                    ),
                children: [
                  TextSpan(
                    text: '$label：',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewActionChip extends StatelessWidget {
  final String label;
  final bool filled;

  const _ReviewActionChip({
    required this.label,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: Icon(
        filled ? Icons.flag_rounded : Icons.check_circle_outline_rounded,
        size: 18,
      ),
      backgroundColor:
          filled ? AuroraColors.purple : Colors.white.withValues(alpha: 0.80),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: filled ? Colors.white : AuroraColors.ink,
            fontWeight: FontWeight.w700,
          ),
      side: BorderSide(color: AuroraColors.purple.withValues(alpha: 0.20)),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocaleText.tr(
                context,
                en: 'Saved as a gentle review signal.',
                zhHans: '已作为温和复盘线索保存。',
                zhHant: '已作為溫和復盤線索保存。',
                ja: 'やさしいふり返りの手がかりとして残しました。',
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReviewSection extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final List<String> items;
  final Color color;

  const _ReviewSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuroraChip(label: number, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AuroraColors.muted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              AppLocaleText.tr(
                context,
                en: 'No clear pattern yet. Keep it as a small observation.',
                zhHans: '现在还没有很清楚的模式，先把它当作小观察。',
                zhHant: '現在還沒有很清楚的模式，先把它當作小觀察。',
                ja: 'まだはっきりしたパターンではありません。小さな観察として残します。',
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AuroraColors.muted, height: 1.45),
            )
          else
            ...items.take(3).map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: color.withValues(alpha: 0.12)),
                    ),
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AuroraColors.ink,
                            height: 1.45,
                          ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
