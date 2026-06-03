import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/today_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_daily_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('repeat_area_preference', 'emotion_stress');
  await prefs.setString('response_style_preference', 'gentle');

  final meViewModel = MeViewModel();
  await meViewModel.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TodayViewModel(EvidenceTodayRepository()),
        ),
        ChangeNotifierProvider<MeViewModel>.value(value: meViewModel),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        debugShowCheckedModeBanner: false,
        home: TodayPage(),
      ),
    ),
  );
}

class EvidenceTodayRepository extends TodayRepository {
  List<RecentSignalModel> _signals = [
    _signal(
      signalCardId: 'sig_online_001',
      content: 'Normal online save: this entry is already a SignalCard.',
      acknowledgement:
          'Saved AI reply: this reply is fixed and not regenerated later.',
      userConfirmation: 'edited',
      migrationStatus: 'native',
    ),
    _signal(
      signalCardId: 'draft_unreachable_001',
      content: 'Backend unreachable draft: this text stays on device first.',
      acknowledgement:
          'Local fallback: saved locally, then retry sync when the network returns.',
      isLocalDraft: true,
      syncFailed: true,
      migrationStatus: 'local_draft',
    ),
    _legacySignal(),
  ];

  EvidenceTodayRepository()
      : super(
          localCaptureRepository: LocalCaptureRepository(
            LocalDatabase(dbPathOverride: 'v3b_evidence.db'),
          ),
          localDailySnapshotRepository: LocalDailySnapshotRepository(
            LocalDatabase(dbPathOverride: 'v3b_evidence_daily.db'),
          ),
          aiRepository: AiRepository(
            ApiClient(
              baseUrl: 'https://example.invalid',
              userId: 'v3b-evidence-user',
            ),
          ),
        );

  @override
  Future<Map<String, dynamic>> fetchToday() async {
    return {
      'insight': TodayInsightModel(
        text:
            'Today Summary is built from SignalCard data while preserving raw input.',
      ),
      'pendingQuestion': null,
      'bestAction': DailyBestActionModel(
        text:
            'Today try-next: keep one small real signal visible before analysis.',
      ),
      'recentSignals': _signals,
    };
  }

  @override
  Future<void> retryPendingDrafts() async {
    _signals = _signals
        .map(
          (signal) => signal.signalCardId == 'draft_unreachable_001'
              ? _signal(
                  signalCardId: 'sig_retry_synced_001',
                  content:
                      'Retry synced draft: the original local text is now remote.',
                  acknowledgement:
                      'Retry success: draft became a synced SignalCard.',
                  migrationStatus: 'synced',
                )
              : signal,
        )
        .toList();
  }

  @override
  Future<void> confirmSignalCard({
    required String signalCardId,
    required String userConfirmation,
    Map<String, dynamic> userCorrectionJson = const {},
  }) async {
    _signals = _signals
        .map(
          (signal) => signal.signalCardId == signalCardId
              ? _cloneSignal(
                  signal,
                  userConfirmation: userConfirmation,
                  userCorrectionJson: userCorrectionJson,
                )
              : signal,
        )
        .toList();
  }
}

RecentSignalModel _signal({
  required String signalCardId,
  required String content,
  required String acknowledgement,
  String userConfirmation = 'unconfirmed',
  String migrationStatus = 'native',
  bool isLocalDraft = false,
  bool syncFailed = false,
}) {
  return RecentSignalModel(
    id: signalCardId.replaceFirst('sig_', 'raw_'),
    signalCardId: signalCardId,
    content: content,
    createdAt: DateTime(2026, 5, 29, 10, 15),
    localDate: '2026-05-29',
    timezone: 'Asia/Tokyo',
    acknowledgement: acknowledgement,
    emotion: 'neutral',
    intensity: 'low',
    scene: 'daily_life',
    friction: isLocalDraft ? 'backend_unreachable' : 'task_switching',
    energyLoad: isLocalDraft ? 'neutral' : 'recovering',
    userConfirmation: userConfirmation,
    userCorrectionJson: userConfirmation == 'edited'
        ? const {'edited_text': 'edited correction is persisted'}
        : const {},
    migrationStatus: migrationStatus,
    isLocalDraft: isLocalDraft,
    syncFailed: syncFailed,
    includedInSummary: true,
  );
}

RecentSignalModel _legacySignal() {
  return RecentSignalModel(
    id: 'raw_legacy_001',
    signalCardId: 'sig_legacy_001',
    content:
        'Legacy record: yesterday night I was tired but still finished it.',
    createdAt: DateTime(2026, 5, 28, 23, 40),
    localDate: '2026-05-28',
    timezone: 'Asia/Tokyo',
    acknowledgement:
        'Old AI reply: this is the reply saved at the time of the original entry.',
    emotion: 'negative',
    intensity: 'medium',
    scene: 'work',
    friction: 'overload',
    energyLoad: 'draining',
    userConfirmation: 'unconfirmed',
    includedInSummary: true,
    includedInWeekly: true,
    isLegacy: true,
    migrationStatus: 'migrated',
  );
}

RecentSignalModel _cloneSignal(
  RecentSignalModel signal, {
  required String userConfirmation,
  required Map<String, dynamic> userCorrectionJson,
}) {
  return RecentSignalModel(
    id: signal.id,
    signalCardId: signal.signalCardId,
    content: signal.content,
    createdAt: signal.createdAt,
    localDate: signal.localDate,
    timezone: signal.timezone,
    acknowledgement: signal.acknowledgement,
    observation: signal.observation,
    tryNext: signal.tryNext,
    emotion: signal.emotion,
    intensity: signal.intensity,
    scene: signal.scene,
    friction: signal.friction,
    positiveSignal: signal.positiveSignal,
    energyLoad: signal.energyLoad,
    sceneTags: signal.sceneTags,
    intentTags: signal.intentTags,
    userConfirmation: userConfirmation,
    userCorrectionJson: userCorrectionJson,
    includedInSummary: signal.includedInSummary,
    includedInWeekly: signal.includedInWeekly,
    includedInJourney: signal.includedInJourney,
    isLegacy: signal.isLegacy,
    migrationStatus: signal.migrationStatus,
    isLocalDraft: signal.isLocalDraft,
    syncFailed: signal.syncFailed,
  );
}
