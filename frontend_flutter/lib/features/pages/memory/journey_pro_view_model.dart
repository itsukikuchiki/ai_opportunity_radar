import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/journey_pro_repository.dart';
import '../../../core/models/journey_pro_models.dart';
import '../../../shared/states/load_state.dart';

class JourneyProViewModel extends ChangeNotifier {
  final JourneyProRepository repository;

  LoadState loadState = LoadState.initial;
  JourneyProReportModel? report;
  String? errorMessage;

  JourneyProViewModel(this.repository);

  Future<void> load({String? selectedMonthKey}) async {
    loadState = LoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      report = await repository.fetchThreeMonthChange(
        selectedMonthKey: selectedMonthKey ?? report?.selectedMonthKey,
      );
      loadState = report?.hasData == true ? LoadState.ready : LoadState.empty;
    } catch (error) {
      report = null;
      errorMessage = error.toString();
      loadState = LoadState.error;
    }
    notifyListeners();
  }

  bool get canMoveToNextMonth =>
      report != null && report!.selectedMonthKey != repository.currentMonthKey;

  Future<void> moveByMonths(int offset) async {
    final base = _parseMonthKey(report?.selectedMonthKey) ??
        _parseMonthKey(repository.currentMonthKey)!;
    final shifted = DateTime(base.year, base.month + offset);
    await load(selectedMonthKey: _monthKey(shifted));
  }

  Future<void> retry() => load(
        selectedMonthKey: report?.selectedMonthKey,
      );

  DateTime? _parseMonthKey(String? value) {
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value ?? '');
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return DateTime(year, month);
  }

  String _monthKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month';
  }
}
