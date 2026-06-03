import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/today_models.dart';
import '../../../shared/widgets/empty_state_block.dart';
import 'today_view_model.dart';

class TodayDiaryPage extends StatefulWidget {
  const TodayDiaryPage({super.key});

  @override
  State<TodayDiaryPage> createState() => _TodayDiaryPageState();
}

class _TodayDiaryPageState extends State<TodayDiaryPage> {
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final signals = context.watch<TodayViewModel>().state.recentSignals;
    final grouped = _groupSignals(signals);
    final dayKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Diary',
            zhHans: '手帐',
            zhHant: '手帳',
            ja: '手帳',
          ),
        ),
      ),
      body: dayKeys.isEmpty
          ? EmptyStateBlock(
              icon: Icons.menu_book_outlined,
              title: AppLocaleText.tr(
                context,
                en: 'No diary records yet',
                zhHans: '手帐里还没有记录',
                zhHant: '手帳裡還沒有記錄',
                ja: '手帳にはまだ記録がありません',
              ),
              subtitle: AppLocaleText.tr(
                context,
                en: 'Things you save in Today will appear here by date.',
                zhHans: '你在今天保存的内容，会按日期放在这里。',
                zhHant: '你在今天保存的內容，會按日期放在這裡。',
                ja: '今日に保存した内容が、日付ごとにここへ並びます。',
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Swipe left to turn to an earlier day.',
                            zhHans: '向左滑动，翻到更早的一天。',
                            zhHant: '向左滑動，翻到更早的一天。',
                            ja: '左にスワイプすると、前の日へめくれます。',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '${_pageIndex + 1} / ${dayKeys.length}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    key: const ValueKey('today-diary-page-view'),
                    itemCount: dayKeys.length,
                    onPageChanged: (index) =>
                        setState(() => _pageIndex = index),
                    itemBuilder: (context, index) {
                      final dayKey = dayKeys[index];
                      return _DiaryDayPage(
                        dayKey: dayKey,
                        signals: grouped[dayKey]!,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Map<String, List<RecentSignalModel>> _groupSignals(
    List<RecentSignalModel> signals,
  ) {
    final grouped = <String, List<RecentSignalModel>>{};
    for (final signal in signals) {
      final key = signal.localDateKey();
      if (key.isEmpty) continue;
      grouped.putIfAbsent(key, () => []).add(signal);
    }
    for (final items in grouped.values) {
      items.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
    }
    return grouped;
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.today);
    }
  }
}

class _DiaryDayPage extends StatelessWidget {
  final String dayKey;
  final List<RecentSignalModel> signals;

  const _DiaryDayPage({
    required this.dayKey,
    required this.signals,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Text(dayKey, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          AppLocaleText.tr(
            context,
            en: '${signals.length} saved signals',
            zhHans: '保存了 ${signals.length} 条信号',
            zhHant: '保存了 ${signals.length} 條信號',
            ja: '${signals.length} 件のシグナル',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        for (final signal in signals) ...[
          _DiarySignalCard(signal: signal),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _DiarySignalCard extends StatelessWidget {
  final RecentSignalModel signal;

  const _DiarySignalCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reply = signal.acknowledgement?.trim();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatTime(signal.createdAt),
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            if (signal.isLibrarySaved)
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Saved from Signal Library',
                  zhHans: '来自信号库的观察',
                  zhHant: '來自信號庫的觀察',
                  ja: 'シグナルライブラリから保存',
                ),
                style: theme.textTheme.labelLarge,
              ),
            if (signal.isLibrarySaved) const SizedBox(height: 6),
            Text(
              signal.content.trim().isEmpty
                  ? _libraryTitle(signal)
                  : signal.content,
              style: theme.textTheme.bodyLarge,
            ),
            if (reply != null && reply.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(reply),
              ),
            ],
            if (_statusLabels(context).isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statusLabels(context)
                    .map(
                      (label) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer
                              .withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(label, style: theme.textTheme.labelSmall),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '--:--';
    final local = time.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _libraryTitle(RecentSignalModel signal) {
    return signal.rawPayloadJson['title']?.toString().trim() ??
        signal.rawPayloadJson['abstract_pattern']?.toString().trim() ??
        '';
  }

  List<String> _statusLabels(BuildContext context) {
    return [
      if (signal.isLegacy)
        AppLocaleText.tr(
          context,
          en: 'Imported',
          zhHans: '旧记录已导入',
          zhHant: '舊記錄已導入',
          ja: '移行済み',
        ),
      if (signal.isLocalDraft)
        AppLocaleText.tr(
          context,
          en: 'Saved on device',
          zhHans: '已保存在本机',
          zhHant: '已保存在本機',
          ja: '端末に保存済み',
        ),
      if (signal.syncFailed)
        AppLocaleText.tr(
          context,
          en: 'Waiting to sync',
          zhHans: '等待同步',
          zhHant: '等待同步',
          ja: '同期待ち',
        ),
      if (signal.isLibrarySaved)
        AppLocaleText.tr(
          context,
          en: 'Private observation',
          zhHans: '私密观察',
          zhHant: '私密觀察',
          ja: 'プライベート観察',
        ),
    ];
  }
}
