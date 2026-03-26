import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/states/load_state.dart';
import 'weekly_view_model.dart';

class WeeklyPage extends StatelessWidget {
  const WeeklyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeeklyViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (vm.loadState) {
          LoadState.loading => const Center(child: CircularProgressIndicator()),
          LoadState.error => Text(vm.errorMessage ?? 'Error'),
          LoadState.empty => const Text('这一周的信号还不够多，我还不想太早下判断。'),
          _ => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vm.weeklyInsight?.keyInsight ?? '', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('Best Action: ${vm.weeklyInsight?.bestAction ?? ''}'),
                const SizedBox(height: 12),
                if (!(vm.weeklyInsight?.feedbackSubmitted ?? false))
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(onPressed: () => vm.submitFeedback('said_right'), child: const Text('说中了')),
                      OutlinedButton(onPressed: () => vm.submitFeedback('somewhat'), child: const Text('有一点')),
                      OutlinedButton(onPressed: () => vm.submitFeedback('not_right'), child: const Text('不太对')),
                    ],
                  )
                else
                  const Text('本周反馈已记录。'),
              ],
            ),
        },
      ),
    );
  }
}
