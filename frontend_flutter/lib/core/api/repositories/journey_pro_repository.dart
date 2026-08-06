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

/// Builds the Journey Pro full-history factual change projection.
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
  }) {
    return fetchFullHistoryChange(selectedMonthKey: selectedMonthKey);
  }

  Future<JourneyProReportModel> fetchFullHistoryChange({
    String? selectedMonthKey,
  }) async {
    final now = nowLoader().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonth = DateTime(today.year, today.month);
    final periodEnd = DateTime(currentMonth.year, currentMonth.month, 0);
    final latestCompletedMonth = DateTime(periodEnd.year, periodEnd.month);
    final installationDate = await _installationDate();
    final firstAppMonth = DateTime(
      installationDate.year,
      installationDate.month,
    );
    final hasCompletedAppMonth = !firstAppMonth.isAfter(latestCompletedMonth);

    final aggregation = hasCompletedAppMonth
        ? await _loadAggregation(
            selectedMonth: latestCompletedMonth,
            today: periodEnd,
          )
        : null;
    // Journey Pro spans the complete local app history. The monthly
    // aggregation above stays scoped to the latest completed month, so it
    // cannot be used as the source of the full-history timeline. Current-month
    // facts are deliberately excluded everywhere in this report.
    final eligibleSignals = hasCompletedAppMonth
        ? eligibilityService.filter(
            await localCaptureRepository.listSignalCardsBetween(
              startDate: _dateKey(installationDate),
              endDate: _dateKey(periodEnd),
            ),
            SignalEligibilityStage.journey,
          )
        : const <RecentSignalModel>[];
    final periodStart = hasCompletedAppMonth ? firstAppMonth : periodEnd;
    final monthStarts = <DateTime>[];
    if (hasCompletedAppMonth) {
      for (var cursor = periodStart;
          !cursor.isAfter(latestCompletedMonth);
          cursor = DateTime(cursor.year, cursor.month + 1)) {
        monthStarts.add(cursor);
      }
    }

    final months = <JourneyProMonthChangeModel>[];
    for (var index = 0; index < monthStarts.length; index += 1) {
      final start = monthStarts[index];
      final naturalEnd = DateTime(start.year, start.month + 1)
          .subtract(const Duration(days: 1));
      months.add(
        _monthProjection(
          eligibleSignals,
          start: start,
          end: naturalEnd,
        ),
      );
    }

    final observationRows = hasCompletedAppMonth
        ? await localObservationRepository?.listForPeriod(
              startDate: _dateKey(periodStart),
              endDate: _dateKey(periodEnd),
            ) ??
            const <Map<String, Object?>>[]
        : const <Map<String, Object?>>[];
    final reportMonthKey = _monthKey(latestCompletedMonth);

    return JourneyProReportModel(
      selectedMonthKey: reportMonthKey,
      periodStart: _dateKey(periodStart),
      periodEnd: _dateKey(periodEnd),
      sourceHash: _buildSourceHash(
        selectedMonthKey: reportMonthKey,
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
    return _monthKey(DateTime(now.year, now.month, 0));
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
    final now = nowLoader().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final loaded = await installationDateLoader?.call();
    if (loaded == null) return today;
    final local = loaded.toLocal();
    final normalized = DateTime(local.year, local.month, local.day);
    if (normalized.isAfter(today) || normalized.year < 2020) return today;
    return normalized;
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
    final themeCounts = <String, int>{};
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
      final themeId = _themeId(signal, fallbackDomainId: domainId);
      themeCounts[themeId] = (themeCounts[themeId] ?? 0) + 1;
    }
    return JourneyProMonthChangeModel(
      monthKey: _monthKey(start),
      periodStart: _dateKey(start),
      periodEnd: _dateKey(end),
      signalCount: signalIds.length,
      activeDayCount: activeDates.length,
      energyStateCounts: energyStateCounts,
      domainCounts: domainCounts,
      themeCounts: themeCounts,
    );
  }

  String _domainId(RecentSignalModel signal) {
    return FocusDomains.classifyId(
      explicitIds: [
        ..._stringValues(signal.userCorrectionJson['focus_domain_id']),
        ..._stringValues(signal.userCorrectionJson['category']),
        ..._stringValues(signal.rawPayloadJson['focus_domain_id']),
        ..._stringValues(signal.rawPayloadJson['focus_domain_ids']),
        ..._stringValues(signal.rawPayloadJson['category']),
      ],
      taxonomyTokens: [
        ..._stringValues(signal.rawPayloadJson['domain_tags']),
        ..._stringValues(signal.rawPayloadJson['focus_domains']),
        ..._stringValues(signal.rawPayloadJson['scene_tags']),
        ...signal.sceneTags,
        signal.scene,
      ],
      textEvidence: _classificationText(signal),
    );
  }

  String _themeId(
    RecentSignalModel signal, {
    required String fallbackDomainId,
  }) {
    return FocusDomains.classifyId(
      taxonomyTokens: [
        ..._stringValues(signal.rawPayloadJson['theme_id']),
        ..._stringValues(signal.rawPayloadJson['theme']),
        ...signal.intentTags,
        ...signal.sceneTags,
        signal.scene,
      ],
      textEvidence: _classificationText(signal),
      fallbackId: fallbackDomainId,
    );
  }

  List<String?> _classificationText(RecentSignalModel signal) {
    return <String?>[
      signal.content,
      signal.observation,
      signal.tryNext,
      signal.friction,
      signal.positiveSignal,
      signal.energyLoad,
      ..._stringValues(signal.rawPayloadJson['title']),
      ..._stringValues(signal.rawPayloadJson['note']),
      ..._stringValues(signal.userCorrectionJson['content']),
      ..._stringValues(signal.userCorrectionJson['text']),
    ];
  }

  List<String> _stringValues(Object? raw) {
    if (raw is Iterable) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? const <String>[] : <String>[value];
  }

  String _buildSourceHash({
    required String selectedMonthKey,
    required JourneyAggregationModel? aggregation,
    required Iterable<RecentSignalModel> fallbackSignals,
    required List<Map<String, Object?>> observationRows,
  }) {
    final source = <String>[
      'journey_pro_v4_completed_months',
      selectedMonthKey,
    ];
    // Always hash the same complete-history Signal set that is projected into
    // the report. Latest-completed-month aggregation remains contextual
    // material only.
    final signals = fallbackSignals.toList();
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

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
