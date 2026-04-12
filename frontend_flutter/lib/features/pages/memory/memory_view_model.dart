import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/memory_repository.dart';
import '../../../core/models/memory_models.dart';
import '../../../shared/states/load_state.dart';

class MemoryViewModel extends ChangeNotifier {
  final MemoryRepository repository;

  LoadState loadState = LoadState.initial;
  MemorySummaryModel? summary;
  String? errorMessage;

  MemoryViewModel(this.repository) {
    load();
  }

  Future<void> load() async {
    loadState = LoadState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      summary = await repository.fetchMemorySummary();
      loadState = summary == null ? LoadState.empty : LoadState.ready;
    } catch (e) {
      errorMessage = e.toString();
      loadState = LoadState.error;
    }

    notifyListeners();
  }

  Future<void> retry() => load();
}
