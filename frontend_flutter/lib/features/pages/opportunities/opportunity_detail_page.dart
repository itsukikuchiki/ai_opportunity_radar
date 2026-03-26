import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/states/load_state.dart';
import 'opportunity_detail_view_model.dart';

class OpportunityDetailPage extends StatefulWidget {
  final String opportunityId;
  const OpportunityDetailPage({super.key, required this.opportunityId});

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
    return Scaffold(
      appBar: AppBar(title: const Text('Opportunity Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (vm.loadState) {
          LoadState.loading => const Center(child: CircularProgressIndicator()),
          LoadState.error => Text(vm.errorMessage ?? 'Error'),
          _ => vm.detail == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vm.detail!.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(vm.detail!.whyThisOpportunity ?? ''),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(onPressed: () => vm.submitFeedback('want_to_try'), child: const Text('想试试')),
                        OutlinedButton(onPressed: () => vm.submitFeedback('too_early'), child: const Text('还太早')),
                        OutlinedButton(onPressed: () => vm.submitFeedback('not_this'), child: const Text('不是这个')),
                      ],
                    ),
                  ],
                ),
        },
      ),
    );
  }
}
