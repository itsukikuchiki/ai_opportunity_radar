import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_locale_text.dart';
import '../../../shared/states/load_state.dart';
import 'opportunity_detail_view_model.dart';

class OpportunityDetailPage extends StatefulWidget {
  final String opportunityId;

  const OpportunityDetailPage({
    super.key,
    required this.opportunityId,
  });

  @override
  State<OpportunityDetailPage> createState() => _OpportunityDetailPageState();
}

class _OpportunityDetailPageState extends State<OpportunityDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OpportunityDetailViewModel>().load(widget.opportunityId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OpportunityDetailViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Opportunity Detail',
            zhHans: '机会详情',
            zhHant: '機會詳情',
            ja: '機会の詳細',
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (vm.loadState) {
          LoadState.loading => const Center(
              child: CircularProgressIndicator(),
            ),
          LoadState.error => Text(
              vm.errorMessage ??
                  AppLocaleText.tr(
                    context,
                    en: 'Something went wrong.',
                    zhHans: '加载失败了。',
                    zhHant: '載入失敗了。',
                    ja: '読み込みに失敗しました。',
                  ),
              style: theme.textTheme.bodyLarge,
            ),
          _ => vm.detail == null
              ? Center(
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'No detail available yet.',
                      zhHans: '暂时还没有可展示的详情。',
                      zhHant: '暫時還沒有可展示的詳情。',
                      ja: 'まだ表示できる詳細がありません。',
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vm.detail!.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(vm.detail!.whyThisOpportunity ?? ''),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () => vm.submitFeedback('want_to_try'),
                          child: Text(
                            AppLocaleText.tr(
                              context,
                              en: 'Want to try',
                              zhHans: '想试试',
                              zhHant: '想試試',
                              ja: '試してみたい',
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => vm.submitFeedback('too_early'),
                          child: Text(
                            AppLocaleText.tr(
                              context,
                              en: 'Too early',
                              zhHans: '还太早',
                              zhHant: '還太早',
                              ja: 'まだ早い',
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => vm.submitFeedback('not_this'),
                          child: Text(
                            AppLocaleText.tr(
                              context,
                              en: 'Not this one',
                              zhHans: '不是这个',
                              zhHant: '不是這個',
                              ja: 'これは違う',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        },
      ),
    );
  }
}
