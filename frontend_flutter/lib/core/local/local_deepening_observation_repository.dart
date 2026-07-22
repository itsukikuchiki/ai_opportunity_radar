import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../eligibility/signal_eligibility_service.dart';
import '../models/deepening_observation_models.dart';
import '../models/today_models.dart';
import 'local_capture_repository.dart';
import 'local_database.dart';

/// Persistence for an explicitly adopted "下周深化观察" question.
///
/// Plans remain read-only analytical context: no plan can create a Signal,
/// enter Today, create a Life Experiment, or schedule a notification.
class LocalDeepeningObservationRepository {
  final LocalDatabase localDatabase;
  final LocalCaptureRepository localCaptureRepository;
  final String localUserId;
  final DateTime Function() nowLoader;
  final SignalEligibilityService eligibilityService;
  final Uuid _uuid = const Uuid();

  LocalDeepeningObservationRepository({
    required this.localDatabase,
    required this.localCaptureRepository,
    this.localUserId = 'local',
    DateTime Function()? nowLoader,
    SignalEligibilityService? eligibilityService,
  })  : nowLoader = nowLoader ?? DateTime.now,
        eligibilityService =
            eligibilityService ?? const SignalEligibilityService();

  /// Adoption is idempotent and enforces at most one proposal for each source
  /// week. Declining is represented by no call and therefore writes nothing.
  Future<DeepeningObservationPlan> adopt(
    DeepeningObservationProposal proposal,
  ) async {
    final db = await localDatabase.database;
    final existing = await db.query(
      'observation_plans',
      where: 'local_user_id = ? AND source_week_start = ?',
      whereArgs: [localUserId, proposal.sourceWeekStart],
      limit: 1,
    );
    if (existing.isNotEmpty) return _fromRow(existing.first);

    final sourceStart = DateTime.tryParse(proposal.sourceWeekStart);
    if (sourceStart == null) {
      throw ArgumentError.value(
        proposal.sourceWeekStart,
        'proposal.sourceWeekStart',
        'invalid_local_week_start',
      );
    }
    final now = nowLoader().toUtc();
    final plan = DeepeningObservationPlan(
      id: 'obsplan_${_uuid.v4().replaceAll('-', '').substring(0, 16)}',
      localUserId: localUserId,
      sourceWeekStart: proposal.sourceWeekStart,
      sourceWeekEnd: proposal.sourceWeekEnd,
      targetWeekStart: _dateKey(sourceStart.add(const Duration(days: 7))),
      question: proposal.question.trim(),
      whatToWatch: _normalizedStrings(proposal.whatToWatch),
      sourceSignalCardIds: _normalizedStrings(proposal.sourceSignalCardIds),
      sourceHash: proposal.sourceHash,
      status: DeepeningObservationPlanStatus.planned,
      createdAt: now,
    );
    await db.insert(
      'observation_plans',
      _toRow(plan),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final stored = await db.query(
      'observation_plans',
      where: 'local_user_id = ? AND source_week_start = ?',
      whereArgs: [localUserId, proposal.sourceWeekStart],
      limit: 1,
    );
    return stored.isEmpty ? plan : _fromRow(stored.first);
  }

  Future<DeepeningObservationPlan?> forTargetWeek(DateTime day) async {
    final db = await localDatabase.database;
    final target = _dateKey(_startOfWeek(day));
    final rows = await db.query(
      'observation_plans',
      where: 'local_user_id = ? AND target_week_start = ?',
      whereArgs: [localUserId, target],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Resolves only after the target week has ended. Before then the plan stays
  /// planned, which prevents a partial week from being presented as a result.
  Future<DeepeningObservationPlan?> resolveCompletedTargetWeek(
    DateTime day,
  ) async {
    final plan = await forTargetWeek(day);
    if (plan == null ||
        plan.status == DeepeningObservationPlanStatus.resolved) {
      return plan;
    }
    final targetStart = DateTime.tryParse(plan.targetWeekStart);
    if (targetStart == null) return plan;
    final targetEnd = targetStart.add(const Duration(days: 6));
    // The target Sunday is still part of the observation window. Resolve only
    // when the next Monday begins, so the whole natural week is available.
    if (!_dateOnly(nowLoader()).isAfter(targetEnd)) return plan;

    final signals = eligibilityService.filter(
      await localCaptureRepository.listSignalCardsBetween(
        startDate: plan.targetWeekStart,
        endDate: _dateKey(targetEnd),
      ),
      SignalEligibilityStage.weekly,
    );
    final matched =
        signals.where((signal) => _matchesPlan(signal, plan)).toList();
    final result = _resultFor(signals: signals, matched: matched, plan: plan);
    final updated = DeepeningObservationPlan(
      id: plan.id,
      localUserId: plan.localUserId,
      sourceWeekStart: plan.sourceWeekStart,
      sourceWeekEnd: plan.sourceWeekEnd,
      targetWeekStart: plan.targetWeekStart,
      question: plan.question,
      whatToWatch: plan.whatToWatch,
      sourceSignalCardIds: plan.sourceSignalCardIds,
      sourceHash: plan.sourceHash,
      status: DeepeningObservationPlanStatus.resolved,
      resultStatus: result.$1,
      resultSummary: result.$2,
      resultSignalCardIds: matched
          .map((signal) => signal.signalCardId ?? signal.id ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false),
      createdAt: plan.createdAt,
      resolvedAt: nowLoader().toUtc(),
    );
    final db = await localDatabase.database;
    await db.update(
      'observation_plans',
      _toRow(updated),
      where: 'id = ? AND status = ?',
      whereArgs: [plan.id, DeepeningObservationPlanStatus.planned.name],
    );
    return updated;
  }

  /// Resolves the latest fully completed natural week, if it has an adopted
  /// observation plan. This is the cross-week read used by the Weekly surface:
  /// on Monday it resolves the immediately preceding Monday--Sunday target
  /// week, rather than looking for a plan in the new current week.
  Future<DeepeningObservationPlan?> resolveLatestCompletedTargetWeek(
    DateTime now,
  ) {
    final currentWeekStart = _startOfWeek(now);
    final latestCompletedWeekStart = currentWeekStart.subtract(
      const Duration(days: 7),
    );
    return resolveCompletedTargetWeek(latestCompletedWeekStart);
  }

  (DeepeningObservationResultStatus, String) _resultFor({
    required List<RecentSignalModel> signals,
    required List<RecentSignalModel> matched,
    required DeepeningObservationPlan plan,
  }) {
    if (signals.length < 3) {
      return (
        DeepeningObservationResultStatus.notEnoughData,
        '本周记录还不够，暂时不能判断“${plan.question}”。',
      );
    }
    if (matched.length >= 2) {
      return (
        DeepeningObservationResultStatus.supported,
        '本周有 ${matched.length} 条相关 Signal 支持继续观察这个方向，但不代表已经形成因果结论。',
      );
    }
    return (
      DeepeningObservationResultStatus.mixed,
      matched.isEmpty
          ? '本周没有出现足够相关的 Signal；这不是反证，之后仍可按需要继续观察。'
          : '本周只出现 ${matched.length} 条相关 Signal，目前更适合继续观察。',
    );
  }

  bool _matchesPlan(RecentSignalModel signal, DeepeningObservationPlan plan) {
    final text = [
      signal.content,
      signal.scene,
      signal.friction,
      signal.energyLoad,
      signal.emotion,
      signal.positiveSignal,
    ].whereType<String>().join(' ').toLowerCase();
    return plan.whatToWatch.any((raw) {
      final term = raw.trim().toLowerCase();
      return term.isNotEmpty && text.contains(term);
    });
  }

  Map<String, Object?> _toRow(DeepeningObservationPlan plan) => {
        'id': plan.id,
        'local_user_id': plan.localUserId,
        'source_week_start': plan.sourceWeekStart,
        'source_week_end': plan.sourceWeekEnd,
        'target_week_start': plan.targetWeekStart,
        'question': plan.question,
        'what_to_watch_json': jsonEncode(plan.whatToWatch),
        'source_signal_card_ids_json': jsonEncode(plan.sourceSignalCardIds),
        'source_hash': plan.sourceHash,
        'status': plan.status.name,
        'result_status': plan.resultStatus?.name,
        'result_summary': plan.resultSummary,
        'result_signal_card_ids_json': jsonEncode(plan.resultSignalCardIds),
        'created_at': plan.createdAt.toIso8601String(),
        'resolved_at': plan.resolvedAt?.toIso8601String(),
      };

  DeepeningObservationPlan _fromRow(Map<String, Object?> row) {
    final status = row['status']?.toString() == 'resolved'
        ? DeepeningObservationPlanStatus.resolved
        : DeepeningObservationPlanStatus.planned;
    final rawResult = row['result_status']?.toString();
    final resultStatus = switch (rawResult) {
      'supported' => DeepeningObservationResultStatus.supported,
      'mixed' => DeepeningObservationResultStatus.mixed,
      'notEnoughData' ||
      'not_enough_data' =>
        DeepeningObservationResultStatus.notEnoughData,
      _ => null,
    };
    return DeepeningObservationPlan(
      id: row['id']?.toString() ?? '',
      localUserId: row['local_user_id']?.toString() ?? localUserId,
      sourceWeekStart: row['source_week_start']?.toString() ?? '',
      sourceWeekEnd: row['source_week_end']?.toString() ?? '',
      targetWeekStart: row['target_week_start']?.toString() ?? '',
      question: row['question']?.toString() ?? '',
      whatToWatch: _decodeStrings(row['what_to_watch_json']),
      sourceSignalCardIds: _decodeStrings(row['source_signal_card_ids_json']),
      sourceHash: row['source_hash']?.toString() ?? '',
      status: status,
      resultStatus: resultStatus,
      resultSummary: row['result_summary']?.toString(),
      resultSignalCardIds: _decodeStrings(row['result_signal_card_ids_json']),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      resolvedAt: DateTime.tryParse(row['resolved_at']?.toString() ?? ''),
    );
  }

  List<String> _decodeStrings(Object? raw) {
    if (raw is List) return _normalizedStrings(raw.map((item) => '$item'));
    try {
      final decoded = jsonDecode(raw?.toString() ?? '[]');
      return decoded is List
          ? _normalizedStrings(decoded.map((item) => '$item'))
          : const [];
    } catch (_) {
      return const [];
    }
  }

  List<String> _normalizedStrings(Iterable<String> values) => values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);

  DateTime _startOfWeek(DateTime day) {
    final local = _dateOnly(day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  DateTime _dateOnly(DateTime day) => DateTime(day.year, day.month, day.day);

  String _dateKey(DateTime day) {
    final local = _dateOnly(day);
    final month = local.month.toString().padLeft(2, '0');
    final date = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$date';
  }
}
