import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/memory_repository.dart';
import '../../../core/models/memory_models.dart';
import '../../../shared/states/load_state.dart';

class MemoryViewModel extends ChangeNotifier {
  final MemoryRepository repository;

  LoadState loadState = LoadState.initial;
  MemorySummaryModel? summary;
  String? errorMessage;
  bool showFirstDayGate = false;

  MemoryViewModel(this.repository) {
    load();
  }

  bool get hasSummary => summary != null && summary!.hasAnySignals;
  int get weakSignalCount => summary?.weakSignals.length ?? 0;
  int get repeatedPatternCount => summary?.repeatedPatterns.length ?? 0;
  int get stableModeCount => summary?.stableModes.length ?? 0;

  Future<void> load() async {
    loadState = LoadState.loading;
    errorMessage = null;
    showFirstDayGate = false;
    notifyListeners();

    try {
      final result = await repository.fetchMemorySummaryResult();
      summary = result.summary;
      showFirstDayGate = result.isFirstDayGate;

      if (showFirstDayGate) {
        loadState = LoadState.empty;
      } else if (summary == null || !summary!.hasAnySignals) {
        loadState = LoadState.empty;
      } else {
        loadState = LoadState.ready;
      }
    } catch (e) {
      errorMessage = e.toString();
      loadState = LoadState.error;
    }

    notifyListeners();
  }

  Future<void> retry() => load();
}
