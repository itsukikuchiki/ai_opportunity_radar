import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/today_models.dart';

class JournalPage extends StatelessWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Journal view',
            zhHans: '手帐视图',
            zhHant: '手帳視圖',
            ja: '手帳ビュー',
          ),
        ),
      ),
      body: FutureBuilder<List<RecentSignalModel>>(
        future: context.read<AppDependencies>().localCaptureRepository.listRecentSignals(limit: 2000),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final signals = snapshot.data ?? const [];
          if (signals.isEmpty) {
            return Center(
              child: Text(
                AppLocaleText.tr(
                  context,
                  en: 'There are no saved entries yet.',
                  zhHans: '还没有可回看的记录。',
                  zhHant: '還沒有可回看的記錄。',
                  ja: 'まだ振り返れる記録はありません。',
                ),
              ),
            );
          }

          final groups = <String, List<RecentSignalModel>>{};
          for (final signal in signals) {
            final dt = signal.createdAt?.toLocal() ?? DateTime.now();
            final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            groups.putIfAbsent(key, () => []).add(signal);
          }
          final dayKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: dayKeys.length,
            itemBuilder: (context, index) {
              final key = dayKeys[index];
              final items = groups[key]!..sort((a, b) => (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000)));
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: items.map((signal) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatTime(signal.createdAt),
                                    style: Theme.of(context).textTheme.labelMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(signal.content),
                                  if ((signal.acknowledgement ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      signal.acknowledgement!,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                  if ((signal.tryNext ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '→ ${signal.tryNext!}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '--:--';
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
