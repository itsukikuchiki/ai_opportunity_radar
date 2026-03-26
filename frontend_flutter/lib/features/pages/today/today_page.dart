import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/states/load_state.dart';
import 'today_view_model.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TodayViewModel>();
    final state = vm.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: vm.updateInput,
              controller: TextEditingController(text: state.inputText)
                ..selection = TextSelection.collapsed(offset: state.inputText.length),
              decoration: const InputDecoration(
                hintText: '今天有什么让你觉得烦、重复、或想省力？',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(onPressed: () => vm.submitCapture(tagHint: 'friction'), child: const Text('记录摩擦')),
                FilledButton(onPressed: () => vm.submitCapture(tagHint: 'repetition'), child: const Text('记录重复')),
                FilledButton(onPressed: () => vm.submitCapture(tagHint: 'desire'), child: const Text('想自动化')),
              ],
            ),
            if (state.acknowledgement != null) ...[
              const SizedBox(height: 16),
              Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(state.acknowledgement!))),
            ],
            if (state.pendingQuestion != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.pendingQuestion!.question),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: state.pendingQuestion!.options
                            .map((o) => OutlinedButton(
                                  onPressed: () => vm.submitFollowup(o.value),
                                  child: Text(o.label),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              )
            ],
            const SizedBox(height: 16),
            if (state.bestAction != null) Text('Daily Best Action: ${state.bestAction!.text}'),
            const SizedBox(height: 12),
            if (state.loadState == LoadState.loading) const CircularProgressIndicator(),
            if (state.errorMessage != null) Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
