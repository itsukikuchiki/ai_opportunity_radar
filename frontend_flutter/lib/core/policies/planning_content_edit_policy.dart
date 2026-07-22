import '../models/phase3_plus_models.dart';
import '../models/weekly_models.dart';

/// Defines the only planning window in which adopted Life Experiment content
/// can be changed. Progress and feedback events are intentionally outside this
/// policy: they are append-only records.
class PlanningContentEditPolicy {
  const PlanningContentEditPolicy._();

  static bool canEditMicroAction(
    MicroActionModel action, {
    required DateTime now,
  }) {
    if (_isClosed(action.status)) return false;
    final start = _parseLocalDate(action.progressStartDate) ??
        _parseLocalDate(action.plannedDate) ??
        action.adoptedAt?.toLocal() ??
        action.createdAt?.toLocal();
    if (start == null) return false;
    final end = _parseLocalDate(action.progressEndDate) ??
        _dateOnly(start).add(const Duration(days: 6));
    return canEditRange(start: start, end: end, now: now);
  }

  static bool canEditLifeExperiment(
    LifeExperimentModel experiment, {
    required DateTime now,
  }) {
    if (_isClosed(experiment.status)) return false;
    final start = _parseLocalDate(experiment.progressStartDate) ??
        _parseLocalDate(experiment.sourceWeekStart) ??
        experiment.adoptedAt?.toLocal() ??
        experiment.createdAt?.toLocal();
    if (start == null) return false;
    final end = _parseLocalDate(experiment.progressEndDate) ??
        _parseLocalDate(experiment.sourceWeekEnd) ??
        _dateOnly(start).add(const Duration(days: 6));
    return canEditRange(start: start, end: end, now: now);
  }

  static bool canEditRange({
    required DateTime start,
    required DateTime end,
    required DateTime now,
  }) {
    final localStart = _dateOnly(start.toLocal());
    final localEnd = _dateOnly(end.toLocal());
    if (localEnd.isBefore(localStart)) return false;

    final currentWeekStart = startOfWeek(now.toLocal());
    final nextWeekEnd = currentWeekStart.add(const Duration(days: 13));
    return !localEnd.isBefore(currentWeekStart) &&
        !localStart.isAfter(nextWeekEnd);
  }

  static DateTime startOfWeek(DateTime value) {
    final local = _dateOnly(value.toLocal());
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  static bool _isClosed(String rawStatus) {
    final status = rawStatus.trim().toLowerCase();
    return status.contains('pause') ||
        status.contains('stop') ||
        status.contains('archive') ||
        status.contains('complete') ||
        status.contains('finish') ||
        status.contains('dismiss') ||
        status.contains('skip');
  }

  static DateTime? _parseLocalDate(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
