import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/states/load_state.dart';
import 'memory_view_model.dart';

class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MemoryViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Memory')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (vm.loadState) {
          LoadState.loading => const Center(child: CircularProgressIndicator()),
          LoadState.error => Text(vm.errorMessage ?? 'Error'),
          _ => ListView(
              children: [
                Text('Patterns: ${(vm.summary?.patterns.length ?? 0)}'),
                for (final item in vm.summary?.patterns ?? []) ListTile(title: Text((item as Map)['name'].toString()), subtitle: Text((item)['summary'].toString())),
                const Divider(),
                Text('Frictions: ${(vm.summary?.frictions.length ?? 0)}'),
                for (final item in vm.summary?.frictions ?? []) ListTile(title: Text((item as Map)['name'].toString()), subtitle: Text((item)['summary'].toString())),
              ],
            ),
        },
      ),
    );
  }
}
