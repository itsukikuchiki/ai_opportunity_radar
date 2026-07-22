import 'dart:convert';

import '../../eligibility/signal_eligibility_service.dart';
import '../../local/local_capture_repository.dart';
import '../../local/local_journey_aggregation_repository.dart';
import '../../local/local_observation_repository.dart';
import '../../models/energy_budget_models.dart';
import '../../models/journey_pro_models.dart';
import '../../models/today_models.dart';
import '../../preferences/focus_domains.dart';
import 'energy_budget_repository.dart';

typedef JourneyProNowLoader = DateTime Function();
typedef JourneyProInstallationDateLoader = Future<DateTime> Function();

/// Builds the Journey Pro three-natural-month factual change projection.
///
/// Readiness counts only eligible immutable Signal Cards. Once eligible, the
/// projection may use privacy-safe feedback and review history as contextual
/// source-version material, but those facts never increase Signal counts.
/// The report is read-only and owns no dedicated persistence.
class JourneyProRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalJourneyAggregationRepository? journeyAggregationRepository;
  final EnergyBudgetRepository? energyBudgetRepository;
  final LocalObservationRepository? localObservationRepository;
  final String localUserId;
  final SignalEligibilityService eligibilityService;
  final JourneyProNowLoader nowLoader;
  final JourneyProInstallationDateLoader? installationDateLoader;

  const JourneyProRepository({
    required this.localCaptureRepository,
    this.journeyAggregationRepository,
    this.energyBudgetRepository,
    this.localObservationRepository,
    this.localUserId = 'local',
    this.eligibilityService = const SignalEligibilityService(),
    this.nowLoader = DateTime.now,
    this.installationDateLoader,
  });

  Future<JourneyProReportModel> fetchThreeMonthChange({
    String? selectedMonthKey,
  }) async {
    final now = nowLoader().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonth = DateTime(today.year, today.month);
    final requestedMonth = _parseMonthKey(selectedMonthKey);
    final selectedMonth =
        requestedMonth == null || requestedMonth.isAfter(currentMonth)
            ? currentMonth
            : requestedMonth;
    final monthStarts = <DateTime>[
      DateTime(selectedMonth.year, selectedMonth.month - 2),
      DateTime(selectedMonth.year, selectedMonth.month - 1),
      selectedMonth,
    ];
    final periodStart = monthStarts.first;
    final selectedMonthNaturalEnd = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
    ).subtract(const Duration(days: 1));
    final periodEnd =
        selectedMonth == currentMonth ? today : selectedMonthNaturalEnd;

    final aggregation = await _loadAggregation(
      selectedMonth: selectedMonth,
      today: today,
    );
    final eligibleSignals = aggregation == null
        ? eligibilityService.filter(
            await localCaptureRepository.listSignalCardsBetween(
              startDate: _dateKey(periodStart),
              endDate: _dateKey(periodEnd),
            ),
            SignalEligibilityStage.journey,
          )
        : aggregation.sourceSignals;

    final months = <JourneyProMonthChangeModel>[];
    for (var index = 0; index < monthStarts.length; index += 1) {
      final start = monthStarts[index];
      final naturalEnd = DateTime(start.year, start.month + 1)
          .subtract(const Duration(days: 1));
      final end = index == monthStarts.length - 1 ? periodEnd : naturalEnd;
      months.add(
        _monthProjection(
          eligibleSignals,
          start: start,
          end: end,
        ),
      );
    }

    final installationDate = await _installationDate();
    final observationRows = await localObservationRepository?.listForPeriod(
          startDate: _dateKey(installationDate),
          endDate: _dateKey(periodEnd),
        ) ??
        const <Map<String, Object?>>[];

    return JourneyProReportModel(
      selectedMonthKey: _monthKey(selectedMonth),
      periodStart: _dateKey(periodStart),
      periodEnd: _dateKey(periodEnd),
      sourceHash: _buildSourceHash(
        selectedMonthKey: _monthKey(selectedMonth),
        aggregation: aggregation,
        fallbackSignals: eligibleSignals,
        observationRows: observationRows,
      ),
      months: months,
      contextCoverage: _contextCoverage(
        aggregation: aggregation,
        observationRows: observationRows,
      ),
    );
  }

  String get currentMonthKey {
    final now = nowLoader().toLocal();
    return _monthKey(DateTime(now.year, now.month));
  }

  Future<JourneyAggregationModel?> _loadAggregation({
    required DateTime selectedMonth,
    required DateTime today,
  }) async {
    final repository = journeyAggregationRepository;
    if (repository == null) return null;
    final installationDate = await _installationDate();
    return repository.fetchMonth(
      localUserId: localUserId,
      selectedMonth: selectedMonth,
      today: today,
      installationDate: installationDate,
    );
  }

  Future<DateTime> _installationDate() async {
    return installationDateLoader?.call() ??
        DateTime(2000, DateTime.january, 1);
  }

  JourneyProMonthChangeModel _monthProjection(
    Iterable<RecentSignalModel> signals, {
    required DateTime start,
    required DateTime end,
  }) {
    final signalIds = <String>{};
    final activeDates = <String>{};
    final energyStateCounts = <String, int>{
      for (final state in EnergySignalState.values) state.storageValue: 0,
    };
    final domainCounts = <String, int>{};
    for (final signal in signals) {
      final day = DateTime.tryParse(signal.localDateKey())?.toLocal();
      final signalId = _signalIdentity(signal);
      if (day == null || signalId.isEmpty) continue;
      final localDay = DateTime(day.year, day.month, day.day);
      if (localDay.isBefore(start) || localDay.isAfter(end)) continue;
      if (!signalIds.add(signalId)) continue;
      activeDates.add(_dateKey(localDay));

      final energyState = energyBudgetRepository?.classifySignal(signal) ??
          EnergySignalState.fromStorage(signal.energyState);
      energyStateCounts[energyState.storageValue] =
          (energyStateCounts[energyState.storageValue] ?? 0) + 1;
      final domainId = _domainId(signal);
      domainCounts[domainId] = (domainCounts[domainId] ?? 0) + 1;
    }
    return JourneyProMonthChangeModel(
      monthKey: _monthKey(start),
      periodStart: _dateKey(start),
      periodEnd: _dateKey(end),
      signalCount: signalIds.length,
      activeDayCount: activeDates.length,
      energyStateCounts: energyStateCounts,
      domainCounts: domainCounts,
    );
  }

  String _domainId(RecentSignalModel signal) {
    final direct = <String?>[
      signal.rawPayloadJson['focus_domain_id']?.toString(),
      signal.rawPayloadJson['category']?.toString(),
      ...signal.sceneTags,
      signal.scene,
    ];
    final normalized = FocusDomains.normalizeIds(direct);
    return normalized.isEmpty ? 'other' : normalized.first;
  }

  String _buildSourceHash({
    required String selectedMonthKey,
    required JourneyAggregationModel? aggregation,
    required Iterable<RecentSignalModel> fallbackSignals,
    required List<Map<String, Object?>> observationRows,
  }) {
    final source = <String>['journey_pro_v2', selectedMonthKey];
    final signals = aggregation?.sourceSignals ?? fallbackSignals.toList();
    for (final signal in signals.toList()
      ..sort((a, b) => _signalIdentity(a).compareTo(_signalIdentity(b)))) {
      source.add(_stableJson({
        'type': 'signal',
        'id': _signalIdentity(signal),
        'date': signal.localDateKey(),
        'content': signal.content,
        'energy_state': signal.energyState,
        'scene': signal.scene,
        'payload': signal.rawPayloadJson,
        'confirmation': signal.userConfirmation,
      }));
    }
    if (aggregation != null) {
      for (final feedback in aggregation.sourceFeedbackEvents.toList()
        ..sort((a, b) => a.id.compareTo(b.id))) {
        source.add(_stableJson({
          'type': 'feedback',
          'value': feedback.toJson(),
        }));
      }
      for (final review in aggregation.sourceWeeklyReviews.toList()
        ..sort((a, b) => a.weekStart.compareTo(b.weekStart))) {
        source.add(_stableJson({
          'type': 'weekly_review',
          'week_start': review.weekStart,
          'week_end': review.weekEnd,
          'status': review.status,
          'key_insight': review.keyInsight,
          'patterns': review.patterns,
          'frictions': review.frictions,
          'best_action': review.bestAction,
          'snapshot': review.opportunitySnapshot,
          'behavior_patterns': review.behaviorPatterns
              .map((item) => item.toMap())
              .toList(growable: false),
        }));
      }
      for (final experiment in aggregation.sourceExperimentHistory.toList()
        ..sort((a, b) => a.id.compareTo(b.id))) {
        source.add(_stableJson({
          'type': 'experiment',
          'id': experiment.id,
          'status': experiment.status,
          'title': experiment.title,
          'updated_at': experiment.updatedAt?.toIso8601String(),
        }));
      }
      for (final rollup in aggregation.sourceExperimentRollups.toList()
        ..sort((a, b) => _stableJson(a).compareTo(_stableJson(b)))) {
        source.add(_stableJson({'type': 'experiment_rollup', 'value': rollup}));
      }
      for (final version in aggregation.sourcePlanContentVersions.toList()
        ..sort((a, b) => _stableJson(a).compareTo(_stableJson(b)))) {
        source.add(_stableJson({
          'type': 'plan_content_version',
          'value': version,
        }));
      }
    }
    for (final observation in observationRows.toList()
      ..sort((a, b) =>
          (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? ''))) {
      source.add(_stableJson({
        'type': 'observation',
        'id': observation['id'],
        'status': observation['status'],
        'text': observation['observation_text'],
        'source_period_start': observation['source_period_start'],
        'updated_at': observation['updated_at'],
      }));
    }
    return _fnv1a(source.join('\n'));
  }

  JourneyProContextCoverageModel _contextCoverage({
    required JourneyAggregationModel? aggregation,
    required List<Map<String, Object?>> observationRows,
  }) {
    final feedbackEvents = aggregation?.sourceFeedbackEvents ?? const [];
    final reviewFeedbackCount = feedbackEvents.where((event) {
      return event.sourceType.toLowerCase().contains('review');
    }).length;
    return JourneyProContextCoverageModel(
      feedbackCount: feedbackEvents.length - reviewFeedbackCount,
      reviewCount:
          reviewFeedbackCount + (aggregation?.sourceWeeklyReviews.length ?? 0),
      experimentContextCount:
          (aggregation?.sourceExperimentHistory.length ?? 0) +
              (aggregation?.sourceExperimentRollups.length ?? 0) +
              (aggregation?.sourcePlanContentVersions.length ?? 0),
      observationCount: observationRows.length,
    );
  }

  String _stableJson(Object? value) {
    Object? normalize(Object? raw) {
      if (raw is Map) {
        final entries = raw.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return <String, Object?>{
          for (final entry in entries) entry.key: normalize(entry.value),
        };
      }
      if (raw is Iterable) return raw.map(normalize).toList(growable: false);
      if (raw is DateTime) return raw.toIso8601String();
      return raw;
    }

    return jsonEncode(normalize(value));
  }

  String _fnv1a(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _signalIdentity(RecentSignalModel signal) {
    final cardId = signal.signalCardId?.trim() ?? '';
    if (cardId.isNotEmpty) return cardId;
    return signal.id?.trim() ?? '';
  }

  String _monthKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month';
  }

  DateTime? _parseMonthKey(String? value) {
    final normalized = value?.trim() ?? '';
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(normalized);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return DateTime(year, month);
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
