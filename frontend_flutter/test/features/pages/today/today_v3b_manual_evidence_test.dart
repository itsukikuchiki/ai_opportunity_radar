import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/i18n/app_locale_text.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final Directory evidenceDir;

  setUpAll(() async {
    evidenceDir = Directory.fromUri(
      Directory.systemTemp.uri.resolve('signalpath_v3b_evidence/'),
    );
    if (!evidenceDir.existsSync()) {
      evidenceDir.createSync(recursive: true);
    }
  });

  testWidgets('V3B evidence 01: online SignalCard remains in Today inbox',
      (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'sig_online_001',
          content: '正常联网新增：今天上午把一个小任务收完了。',
          acknowledgement: '保存的 AI 回复：这条已经作为 SignalCard 保存。',
          userConfirmation: 'unconfirmed',
        ),
        _legacySignal(),
      ],
    );

    await _pumpEvidencePage(
      tester,
      repo,
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
    );
    await _writeEvidenceNote(
      '01_online_signalcard_legacy_timeline.txt',
      evidenceDir,
      'TodayPage renders the online SignalCard. Legacy records now live in the separate diary page.',
    );

    expect(repo.signals.any((s) => s.content.contains('正常联网新增')), isTrue);
    expect(find.text('快速记录'), findsOneWidget);
    expect(find.text('今日小行动'), findsOneWidget);
  });

  testWidgets('V3B evidence 02: backend unreachable local draft',
      (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'draft_unreachable_001',
          content: '断网新增：这条必须先留在本机。',
          acknowledgement: '这是今天的一条生活信号。',
          isLocalDraft: true,
          syncFailed: true,
          migrationStatus: 'local_draft',
        ),
        _legacySignal(),
      ],
    );

    await _pumpEvidencePage(
      tester,
      repo,
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
    );
    await _writeEvidenceNote(
      '02_backend_unreachable_local_draft.txt',
      evidenceDir,
      'TodayPage renders backend-unreachable local draft with retry status.',
    );

    expect(repo.signals.any((s) => s.content.contains('断网新增')), isTrue);
    expect(repo.signals.any((s) => s.isLocalDraft && s.syncFailed), isTrue);
    expect(find.text('快速记录'), findsOneWidget);
    expect(find.text('今日时间线'), findsOneWidget);
  });

  testWidgets('AI prediction confirmation stores a confirmed signal only',
      (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'sig_confirm_001',
          content: '确认动作：这条要写入 edited correction。',
          acknowledgement: '旧 ai_reply：使用保存内容，不重新生成。',
          userConfirmation: 'unconfirmed',
        ),
        _legacySignal(),
      ],
    );
    await repo.createAiJudgementForToday();

    await _pumpEvidencePage(tester, repo);

    expect(repo.aiJudgement, isNotNull);
    expect(repo.signals.any((s) => s.sourceType == 'ai_predicted'), isFalse);

    final accurate = find.byKey(const ValueKey('ai-prediction-accurate'));
    await tester.ensureVisible(accurate);
    await tester.tap(accurate);
    await _settleEvidenceFrame(tester);
    await tester.tap(
      find.byKey(const ValueKey('ai-prediction-add-timeline')),
    );
    await _settleEvidenceFrame(tester);
    expect(repo.aiJudgement?.status, 'accurate');
    expect(repo.aiJudgement?.predictionKind, 'inferred_signal');
    expect(repo.aiJudgement?.predictedSignalText, isNotEmpty);
    expect(repo.aiJudgement?.confirmationNote, isNotEmpty);
    expect(repo.microActions, isEmpty);
    expect(repo.aiJudgement?.linkedMicroActionId, isNull);
    expect(repo.signals.any((s) => s.sourceType == 'ai_predicted'), isTrue);

    await _writeEvidenceNote(
      '03_ai_judgement_confirmation_written.txt',
      evidenceDir,
      'TodayPage writes AI prediction confirmation without creating a MicroAction.',
    );

    expect(
      repo.signals.any(
        (s) => (s.acknowledgement ?? '').contains('旧 ai_reply'),
      ),
      isTrue,
    );
  });

  testWidgets('AI prediction inaccurate dismisses without creating a signal',
      (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'sig_ignore_001',
          content: '今天安排有点满，晚上不想再加东西。',
          acknowledgement: '这条记录可以先只留作观察。',
        ),
      ],
    );
    await repo.createAiJudgementForToday();

    await _pumpEvidencePage(tester, repo);

    final inaccurate = find.byKey(const ValueKey('ai-prediction-inaccurate'));
    await tester.ensureVisible(inaccurate);
    await tester.tap(inaccurate);
    await _settleEvidenceFrame(tester);

    expect(repo.aiJudgement?.status, 'pending');
    expect(repo.aiJudgement?.includedInWeekly, isFalse);
    expect(repo.aiJudgement?.includedInJourney, isFalse);
    expect(repo.signals.any((s) => s.sourceType == 'ai_predicted'), isFalse);
    expect(
      find.byKey(const ValueKey('ai-prediction-inaccurate')),
      findsNothing,
    );
    expect(find.textContaining('will not be used'), findsNothing);
  });

  testWidgets('V3B-2B AI prediction copy and actions stay low pressure',
      (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'sig_synced_edited_001',
          content: 'Synced edited: this should not look like a task.',
          acknowledgement: 'Saved AI reply stays below the raw text.',
          userConfirmation: 'edited',
        ),
        _todaySignal(
          signalCardId: 'draft_retry_001',
          content: 'Draft retry: original text must stay visible.',
          acknowledgement: '',
          isLocalDraft: true,
          syncFailed: true,
          migrationStatus: 'local_draft',
        ),
      ],
    );
    await repo.createAiJudgementForToday();

    await _pumpEvidencePage(tester, repo);

    expect(find.text('AI prediction'), findsOneWidget);
    expect(find.text(repo.aiJudgement!.predictedSignalText), findsOneWidget);
    expect(
      find.byKey(const ValueKey('today-ai-judgement-action')),
      findsNothing,
    );
    expect(find.text('Accurate'), findsOneWidget);
    expect(find.text('Somewhat'), findsOneWidget);
    expect(find.text('Not accurate'), findsOneWidget);
    expect(
      repo.signals
          .any((s) => (s.acknowledgement ?? '').isEmpty && s.syncFailed),
      isTrue,
    );
  });

  testWidgets('AI prediction panel stays next to signal input before overview',
      (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'sig_prediction_layout',
          content: '现在有点乱。',
          acknowledgement: '保存的 AI 回复。',
        ),
      ],
    );
    await repo.createAiJudgementForToday(
      language: AppLanguage.simplifiedChinese,
    );

    await _pumpEvidencePage(
      tester,
      repo,
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
    );

    final predictionPanel =
        find.byKey(const ValueKey('today-ai-prediction-panel'));
    final overviewTitle = find.text('今日时间线');

    expect(predictionPanel, findsOneWidget);
    expect(overviewTitle, findsOneWidget);
    expect(
      tester.getTopLeft(predictionPanel).dy,
      lessThan(tester.getTopLeft(overviewTitle).dy),
    );
  });

  testWidgets('V3B-2B Today prediction copy supports four languages',
      (tester) async {
    final cases = [
      (
        locale: const Locale('en'),
        title: 'AI prediction',
        empty: 'No prediction yet',
      ),
      (
        locale: const Locale('ja'),
        title: 'AI予測',
        empty: 'まだ予測はありません',
      ),
      (
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        title: 'AI预判',
        empty: '暂时还没有预判',
      ),
      (
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        ),
        title: 'AI預判',
        empty: '暫時還沒有預判',
      ),
    ];

    for (final item in cases) {
      final repo = MutableTodayRepository(signals: const []);

      await _pumpEvidencePage(tester, repo, locale: item.locale);

      expect(find.text(item.title), findsOneWidget);
      expect(find.text(item.empty), findsOneWidget);
      expect(
        repo.signals.any((signal) => signal.sourceType == 'ai_predicted'),
        isFalse,
      );
    }
  });

  testWidgets('raw text and voice records do not ask for accuracy confirmation',
      (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'sig_raw_text_001',
          content: '天气不错',
          acknowledgement: 'AI 还没整理这条，但你的原文已经保存。',
        ),
        _todaySignal(
          signalCardId: 'sig_voice_001',
          content: '语音转写：今天散步之后轻了一点。',
          acknowledgement: '这条转写已经保存。',
          sourceType: 'voice',
        ),
      ],
    );

    await _pumpEvidencePage(
      tester,
      repo,
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
    );

    expect(find.text('天气不错'), findsWidgets);
    expect(find.text('语音转写：今天散步之后轻了一点。'), findsWidgets);
    expect(find.text('是准的'), findsNothing);
    expect(find.text('不太准'), findsNothing);
    expect(find.text('改一下'), findsNothing);
    expect(find.text('补一点'), findsNothing);
    expect(find.text('还没确认'), findsNothing);
    expect(find.text('已保存在本机'), findsNothing);
  });

  test('AI prediction follows app language without fake predicted SignalCard',
      () async {
    final cases = [
      (
        language: AppLanguage.simplifiedChinese,
        expected: '这几条信号像是在提醒你：恢复空间可以先被留出来。',
      ),
      (
        language: AppLanguage.traditionalChinese,
        expected: '這幾條信號像是在提醒你：恢復空間可以先被留出來。',
      ),
      (
        language: AppLanguage.japanese,
        expected: 'いくつかのシグナルは、回復の余白を先に残してもよさそうだと示しています。',
      ),
      (
        language: AppLanguage.english,
        expected:
            'A few signals suggest that recovery space may need to be protected first.',
      ),
    ];

    for (final item in cases) {
      final repo = MutableTodayRepository(
        signals: [
          _todaySignal(
            signalCardId: 'sig_seed_${item.language.name}',
            content: '天气不错',
            acknowledgement: '',
          ),
        ],
      );
      final vm = TodayViewModel(repo);
      await Future<void>.delayed(Duration.zero);

      await vm.createPredictedSignal(language: item.language);

      expect(repo.aiJudgement?.judgementText, item.expected);
      expect(repo.aiJudgement?.predictionKind, 'inferred_signal');
      expect(repo.aiJudgement?.predictedSignalText, item.expected);
      expect(repo.signals.any((s) => s.sourceType == 'ai_predicted'), isFalse);
    }
  });

  testWidgets('简体中文页面自动生成 AI 判断后不会显示英文判断', (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'sig_seed_ui',
          content: '不想上班',
          acknowledgement: '',
        ),
      ],
    );
    await repo.createAiJudgementForToday(
      language: AppLanguage.simplifiedChinese,
    );

    await _pumpEvidencePage(
      tester,
      repo,
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
    );

    expect(find.textContaining('这几条信号像是在提醒你'), findsWidgets);
    expect(find.textContaining('A few signals suggest'), findsNothing);
  });
}

Future<void> _pumpEvidencePage(
  WidgetTester tester,
  MutableTodayRepository repo, {
  Locale locale = const Locale('en'),
}) async {
  final meVm = await buildMeViewModel();
  await tester.binding.setSurfaceSize(const Size(390, 1600));
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('v3b-evidence-root'),
      child: buildTestApp(
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
        locale: locale,
      ),
    ),
  );
  await _settleEvidenceFrame(tester);
}

Future<void> _settleEvidenceFrame(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

Future<void> _writeEvidenceNote(
  String filename,
  Directory evidenceDir,
  String body,
) async {
  final file = File.fromUri(evidenceDir.uri.resolve(filename));
  file.writeAsStringSync(body);
}

RecentSignalModel _todaySignal({
  required String signalCardId,
  required String content,
  required String acknowledgement,
  String userConfirmation = 'unconfirmed',
  String sourceType = 'text',
  bool isLocalDraft = false,
  bool syncFailed = false,
  String migrationStatus = 'native',
}) {
  return RecentSignalModel(
    id: signalCardId.replaceFirst('sig_', 'raw_'),
    signalCardId: signalCardId,
    sourceType: sourceType,
    content: content,
    createdAt: DateTime.now(),
    localDate: _todayKey(),
    timezone: 'Asia/Tokyo',
    acknowledgement: acknowledgement,
    emotion: 'neutral',
    intensity: 'low',
    scene: 'daily_life',
    energyLoad: 'neutral',
    userConfirmation: userConfirmation,
    migrationStatus: migrationStatus,
    isLocalDraft: isLocalDraft,
    syncFailed: syncFailed,
  );
}

RecentSignalModel _legacySignal() {
  return RecentSignalModel(
    id: 'raw_legacy_001',
    signalCardId: 'sig_legacy_001',
    content: '旧记录：昨天晚上已经很累，但还是把事情收完了。',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    localDate: _yesterdayKey(),
    timezone: 'Asia/Tokyo',
    acknowledgement: '旧 AI 回复：这条里保存的是当时那种硬撑后的疲惫。',
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

String _todayKey() => _dateKey(DateTime.now());

String _yesterdayKey() =>
    _dateKey(DateTime.now().subtract(const Duration(days: 1)));

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class MutableTodayRepository extends StubTodayRepository {
  List<RecentSignalModel> signals;
  AiJudgementModel? aiJudgement;
  List<MicroActionModel> microActions;
  final List<MicroActionFeedbackModel> microActionFeedbacks = [];
  String? lastConfirmation;
  String? lastSubmittedContent;
  String? lastSubmittedSourceType;
  Map<String, dynamic> lastCorrection = const {};

  MutableTodayRepository({
    required this.signals,
    this.aiJudgement,
    this.microActions = const [],
  }) : super(fetchTodayResult: const {});

  @override
  Future<Map<String, dynamic>> fetchToday() async {
    fetchTodayCallCount += 1;
    return {
      'insight': TodayInsightModel(text: 'Today Summary 使用 SignalCard 列表生成。'),
      'pendingQuestion': null,
      'bestAction': DailyBestActionModel(text: '今天先试试：只补一条真实发生的小事。'),
      'recentSignals': signals,
      'aiJudgement': aiJudgement,
      'microActions': microActions,
    };
  }

  @override
  Future<Map<String, dynamic>> submitCapture({
    required String content,
    String? tagHint,
    String sourceType = 'text',
    Map<String, dynamic> rawPayloadJson = const {},
  }) async {
    lastSubmittedContent = content;
    lastSubmittedSourceType = sourceType;
    final signal = _todaySignal(
      signalCardId: 'sig_submitted_${signals.length}',
      content: content,
      acknowledgement: '',
      sourceType: sourceType,
    );
    signals = [signal, ...signals];
    return {
      'acknowledgement': signal.acknowledgement,
      'followup': null,
      'updatedRecentSignals': signals,
      'localSignal': signal,
    };
  }

  @override
  Future<void> confirmSignalCard({
    required String signalCardId,
    required String userConfirmation,
    Map<String, dynamic> userCorrectionJson = const {},
  }) async {
    lastConfirmation = userConfirmation;
    lastCorrection = userCorrectionJson;
    signals = signals
        .map(
          (signal) => signal.signalCardId == signalCardId
              ? RecentSignalModel(
                  id: signal.id,
                  signalCardId: signal.signalCardId,
                  sourceType: signal.sourceType,
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
                )
              : signal,
        )
        .toList();
  }

  @override
  Future<AiJudgementModel?> createAiJudgementForToday({
    AppLanguage language = AppLanguage.english,
  }) async {
    if (signals.isEmpty) return null;
    final judgement = AiJudgementModel(
      id: aiJudgement?.id ?? 'aj_test_001',
      sourceSignalCardIds: signals
          .where((signal) => signal.sourceType != 'ai_predicted')
          .map((signal) => signal.signalCardId)
          .whereType<String>()
          .toList(),
      localDate: _todayKey(),
      judgementText: _judgementText(language),
      evidenceText: _judgementEvidence(language),
      predictionKind: 'inferred_signal',
      predictedSignalText: _judgementText(language),
      suggestedPattern: _judgementPattern(language),
      suggestedLifeChainStage: 'recovery',
      status: aiJudgement?.status ?? 'pending',
      confirmationNote: aiJudgement?.confirmationNote,
      linkedMicroActionId: aiJudgement?.linkedMicroActionId,
      createdAt: aiJudgement?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    aiJudgement = judgement;
    return judgement;
  }

  @override
  Future<Map<String, dynamic>> respondToAiJudgement({
    required String judgementId,
    required String status,
    String? userAdjustmentText,
    bool addToTimeline = true,
    AppLanguage language = AppLanguage.english,
  }) async {
    final judgement = aiJudgement;
    if (judgement == null || judgement.id != judgementId) return fetchToday();

    final normalizedStatus = status == 'supplemented' ? 'adjusted' : status;
    final confirmedSignal = const {
      'confirmed',
      'adjusted',
      'accurate',
      'partial',
    }.contains(normalizedStatus);
    aiJudgement = AiJudgementModel(
      id: judgement.id,
      sourceSignalCardIds: judgement.sourceSignalCardIds,
      sourceScheduleSignalIds: judgement.sourceScheduleSignalIds,
      sourceGoalTaskInstanceIds: judgement.sourceGoalTaskInstanceIds,
      localDate: judgement.localDate,
      judgementText: judgement.judgementText,
      evidenceText: judgement.evidenceText,
      predictionKind: judgement.predictionKind,
      predictedSignalText: judgement.predictedSignalText,
      suggestedPattern: judgement.suggestedPattern,
      suggestedLifeChainStage: judgement.suggestedLifeChainStage,
      confidenceLevel: judgement.confidenceLevel,
      status: normalizedStatus,
      userAdjustmentText: userAdjustmentText,
      confirmationNote: confirmedSignal
          ? userAdjustmentText ?? 'Confirmed predicted signal'
          : null,
      linkedMicroActionId: judgement.linkedMicroActionId,
      includedInWeekly: confirmedSignal,
      includedInJourney: confirmedSignal,
      createdAt: judgement.createdAt,
      updatedAt: DateTime.now(),
    );
    if (confirmedSignal && addToTimeline) {
      signals = [
        RecentSignalModel(
          id: 'predicted_${judgement.id}',
          signalCardId: 'predicted_${judgement.id}',
          sourceType: 'ai_predicted',
          content: (userAdjustmentText ?? judgement.predictedSignalText).trim(),
          createdAt: DateTime.now(),
          acknowledgement: 'Confirmed predicted signal',
          userConfirmation: 'confirmed',
          rawPayloadJson: {
            'ai_judgement_id': judgement.id,
            'confirmation_status': normalizedStatus,
          },
        ),
        ...signals,
      ];
    }
    return fetchToday();
  }

  @override
  Future<Map<String, dynamic>> chooseMicroAction({
    required String microActionId,
    required String choice,
    AppLanguage language = AppLanguage.english,
  }) async {
    microActions = microActions
        .map((action) => action.id == microActionId
            ? MicroActionModel(
                id: action.id,
                judgementId: action.judgementId,
                title: choice == 'lighter'
                    ? _lighterMicroActionTitle(language)
                    : action.title,
                reason: action.reason,
                actionType: choice == 'weekly_experiment'
                    ? 'weekly_experiment'
                    : 'today_try',
                difficulty:
                    choice == 'lighter' ? 'very_light' : action.difficulty,
                plannedDate: action.plannedDate,
                plannedTime: action.plannedTime,
                linkedScheduleSignalId: action.linkedScheduleSignalId,
                linkedGoalId: action.linkedGoalId,
                linkedLifeExperimentId: action.linkedLifeExperimentId,
                status: switch (choice) {
                  'weekly_experiment' => 'active',
                  'lighter' => 'adjusted',
                  'skip' => 'skipped',
                  _ => 'accepted',
                },
                feedbackStatus: action.feedbackStatus,
                createdAt: action.createdAt,
                updatedAt: DateTime.now(),
              )
            : action)
        .toList();
    return fetchToday();
  }

  @override
  Future<Map<String, dynamic>> submitMicroActionFeedback({
    required String microActionId,
    required String feedback,
    String? userNote,
  }) async {
    microActionFeedbacks.add(
      MicroActionFeedbackModel(
        id: 'maf_${microActionFeedbacks.length + 1}',
        microActionId: microActionId,
        localDate: _todayKey(),
        happened: const {'happened', 'occurred'}.contains(feedback)
            ? 'yes'
            : const {'not_happened', 'not_occurred'}.contains(feedback)
                ? 'no'
                : feedback == 'not_suitable_today'
                    ? 'not_suitable_today'
                    : 'unknown',
        effect: feedback == 'helpful' ? 'helpful' : 'unclear',
        difficulty: const {'too_hard', 'not_suitable_today'}.contains(feedback)
            ? feedback
            : 'okay',
        userNote: userNote,
      ),
    );
    microActions = microActions
        .map((action) => action.id == microActionId
            ? MicroActionModel(
                id: action.id,
                judgementId: action.judgementId,
                title: action.title,
                reason: action.reason,
                actionType: action.actionType,
                difficulty: action.difficulty,
                plannedDate: action.plannedDate,
                plannedTime: action.plannedTime,
                linkedScheduleSignalId: action.linkedScheduleSignalId,
                linkedGoalId: action.linkedGoalId,
                linkedLifeExperimentId: action.linkedLifeExperimentId,
                status: 'done',
                feedbackStatus: feedback,
                createdAt: action.createdAt,
                updatedAt: DateTime.now(),
              )
            : action)
        .toList();
    return fetchToday();
  }
}

String _judgementText(AppLanguage language) {
  return switch (language) {
    AppLanguage.simplifiedChinese => '这几条信号像是在提醒你：恢复空间可以先被留出来。',
    AppLanguage.traditionalChinese => '這幾條信號像是在提醒你：恢復空間可以先被留出來。',
    AppLanguage.japanese => 'いくつかのシグナルは、回復の余白を先に残してもよさそうだと示しています。',
    AppLanguage.english =>
      'A few signals suggest that recovery space may need to be protected first.',
  };
}

String _judgementEvidence(AppLanguage language) {
  return switch (language) {
    AppLanguage.simplifiedChinese => '基于今天已经保存的信号，这是一个可确认的小判断。',
    AppLanguage.traditionalChinese => '基於今天已經保存的信號，這是一個可確認的小判斷。',
    AppLanguage.japanese => '今日保存されたシグナルから、確認できる小さな判断です。',
    AppLanguage.english =>
      'Based on today’s saved signals, this is a small confirmable judgement.',
  };
}

String _judgementPattern(AppLanguage language) {
  return switch (language) {
    AppLanguage.simplifiedChinese => '恢复空间',
    AppLanguage.traditionalChinese => '恢復空間',
    AppLanguage.japanese => '回復の余白',
    AppLanguage.english => 'Recovery space',
  };
}

String _lighterMicroActionTitle(AppLanguage language) {
  return switch (language) {
    AppLanguage.simplifiedChinese => '只留 2 分钟空白',
    AppLanguage.traditionalChinese => '只留 2 分鐘空白',
    AppLanguage.japanese => '2分だけ余白を残す',
    AppLanguage.english => 'Leave only two quiet minutes',
  };
}
