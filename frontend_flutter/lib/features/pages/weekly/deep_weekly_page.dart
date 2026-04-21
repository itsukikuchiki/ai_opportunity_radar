import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/weekly_models.dart';

class DeepWeeklyPage extends StatelessWidget {
  const DeepWeeklyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Deep Weekly',
            zhHans: 'Deep Weekly',
            zhHant: 'Deep Weekly',
            ja: 'Deep Weekly',
          ),
        ),
      ),
      body: FutureBuilder<DeepWeeklyModel>(
        future: context.read<AppDependencies>().weeklyRepository.fetchDeepWeekly(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final deep = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _SectionCard(
                title: AppLocaleText.tr(
                  context,
                  en: 'This week in one layer deeper',
                  zhHans: '这一周，再往深一层看',
                  zhHant: '這一週，再往深一層看',
                  ja: '今週をもう一段深く見る',
                ),
                body: deep.summary,
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: AppLocaleText.tr(
                  context,
                  en: 'Root tension',
                  zhHans: '底层拉扯',
                  zhHant: '底層拉扯',
                  ja: '根っこの tension',
                ),
                body: deep.rootTension,
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: AppLocaleText.tr(
                  context,
                  en: 'Hidden pattern',
                  zhHans: '隐藏模式',
                  zhHant: '隱藏模式',
                  ja: '隠れた pattern',
                ),
                body: deep.hiddenPattern,
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: AppLocaleText.tr(
                  context,
                  en: 'What to keep watching next week',
                  zhHans: '下周继续看什么',
                  zhHant: '下週繼續看什麼',
                  ja: '来週も見続けること',
                ),
                body: deep.nextFocus,
              ),
              if (deep.keyNodes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Key nodes',
                            zhHans: '关键节点',
                            zhHant: '關鍵節點',
                            ja: 'キーになる点',
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        ...deep.keyNodes.map((node) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('• $node'),
                            )),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _SectionCard(
                title: AppLocaleText.tr(
                  context,
                  en: 'How to use this page',
                  zhHans: '这页怎么用',
                  zhHant: '這頁怎麼用',
                  ja: 'このページの使い方',
                ),
                body: deep.riskNote,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String body;

  const _SectionCard({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(body),
          ],
        ),
      ),
    );
  }
}
