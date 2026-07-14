import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/i18n/app_locale_text.dart';
import 'package:ai_opportunity_radar/core/local/local_candidate_planning_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/models/candidate_models.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/candidates/candidate_hub_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_adopted_plans_section.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  testWidgets('小行动候选页在不足三条时解释门槛且不伪造候选', (tester) async {
    final repository = StubCandidatePlanningRepository(
      microSnapshot: _microSnapshot(count: 2, candidates: const []),
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        providers: [Provider<int>.value(value: 0)],
        child: CandidateHubPage(
          kind: CandidateKind.microAction,
          repositoryOverride: repository,
          nowLoader: () => DateTime(2026, 7, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('记录 3 条信号后开始显示'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('candidate-adopt-selected')), findsNothing);
    expect(repository.adoptedMicroIds, isEmpty);
  });

  testWidgets('小行动候选页最多显示三个并允许一次采纳多个', (tester) async {
    final candidates = List.generate(
      3,
      (index) => MicroActionCandidateModel(
        id: 'candidate-${index + 1}',
        candidateGroupId: 'group-1',
        localUserId: 'local',
        localDate: '2026-07-12',
        rank: index + 1,
        title: '候选行动 ${index + 1}',
        reason: '来自三条符合条件的真实信号。',
        difficulty: 'very_light',
        linkedSignalCardIds: const ['signal-1', 'signal-2', 'signal-3'],
        focusDomainIds: const [],
        status: 'generated',
        sourceHash: 'source-1',
      ),
    );
    final repository = StubCandidatePlanningRepository(
      microSnapshot: _microSnapshot(count: 3, candidates: candidates),
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        providers: [Provider<int>.value(value: 0)],
        child: CandidateHubPage(
          kind: CandidateKind.microAction,
          repositoryOverride: repository,
          nowLoader: () => DateTime(2026, 7, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('候选行动 1'), findsOneWidget);
    expect(find.text('候选行动 2'), findsOneWidget);
    expect(find.text('候选行动 3'), findsOneWidget);
    expect(find.text('可采纳 0–3 个'), findsOneWidget);

    final firstCheckbox = find.descendant(
      of: find.byKey(const ValueKey('candidate-option-candidate-1')),
      matching: find.byType(Checkbox),
    );
    final secondCheckbox = find.descendant(
      of: find.byKey(const ValueKey('candidate-option-candidate-2')),
      matching: find.byType(Checkbox),
    );
    await tester.ensureVisible(firstCheckbox);
    await tester.tap(firstCheckbox);
    await tester.pump();
    await tester.ensureVisible(secondCheckbox);
    await tester.tap(secondCheckbox);
    await tester.pump();
    expect(find.text('采纳已选 2 项'), findsOneWidget);

    final adoptButton = find.byKey(const ValueKey('candidate-adopt-selected'));
    await tester.ensureVisible(adoptButton);
    await tester.tap(adoptButton);
    await tester.pumpAndSettle();
    expect(repository.adoptedMicroIds,
        containsAll(<String>['candidate-1', 'candidate-2']));
    expect(repository.adoptedMicroIds, hasLength(2));
  });

  testWidgets('小实验候选页使用当周门槛，最多显示三个并可多选采纳', (tester) async {
    final candidates = List.generate(
      4,
      (index) => ExperimentCandidateRecord(
        id: 'experiment-candidate-${index + 1}',
        candidateGroupId: 'experiment-group-1',
        localUserId: 'local',
        weekStart: '2026-07-06',
        weekEnd: '2026-07-12',
        rank: index + 1,
        title: '候选实验 ${index + 1}',
        hypothesis: '这个轻量尝试可能有帮助。',
        suggestedAction: '每天试一次。',
        linkedSignalCardIds: const ['signal-1', 'signal-2', 'signal-3'],
        linkedObservationIds: const [],
        confidenceLevel: 'medium',
        metadata: const {},
        status: 'generated',
        sourceHash: 'weekly-source-1',
      ),
    );
    final repository = StubCandidatePlanningRepository(
      microSnapshot: _microSnapshot(count: 3, candidates: const []),
      experimentSnapshot: _experimentSnapshot(
        count: 3,
        candidates: candidates,
      ),
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        providers: [Provider<int>.value(value: 0)],
        child: CandidateHubPage(
          kind: CandidateKind.lifeExperiment,
          repositoryOverride: repository,
          nowLoader: () => DateTime(2026, 7, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('候选实验 1'), findsOneWidget);
    expect(find.text('候选实验 3'), findsOneWidget);
    expect(find.text('候选实验 4'), findsNothing);
    expect(find.text('可采纳 0–3 个'), findsOneWidget);

    for (final id in [
      'experiment-candidate-1',
      'experiment-candidate-3',
    ]) {
      final checkbox = find.descendant(
        of: find.byKey(ValueKey('candidate-option-$id')),
        matching: find.byType(Checkbox),
      );
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
    }

    final adoptButton = find.byKey(const ValueKey('candidate-adopt-selected'));
    expect(find.text('采纳已选 2 项'), findsOneWidget);
    await tester.ensureVisible(adoptButton);
    await tester.tap(adoptButton);
    await tester.pumpAndSettle();

    expect(
      repository.adoptedExperimentIds,
      ['experiment-candidate-1', 'experiment-candidate-3'],
    );
    expect(find.textContaining('七日进度从下周一开始'), findsOneWidget);
  });

  testWidgets('Today 每类最多展示三个已采纳项目并把其余放入查看全部', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final actions = List.generate(4, (index) {
      final action = MicroActionModel(
        id: 'active-action-${index + 1}',
        judgementId: '',
        title: '已采纳行动 ${index + 1}',
        reason: '来自真实信号。',
        status: 'active',
        sourceChanged: index == 0,
      );
      return AdoptedMicroActionProgress(
        action: action,
        progress: _progress(action.id, completed: index),
      );
    });
    final experiments = List.generate(4, (index) {
      final experiment = LifeExperimentModel(
        id: 'active-experiment-${index + 1}',
        localUserId: 'local',
        sourceWeekStart: '2026-07-06',
        sourceWeekEnd: '2026-07-12',
        title: '已采纳实验 ${index + 1}',
        hypothesis: '验证一个轻量变化。',
        suggestedAction: '每天只试一次。',
        linkedSignalCardIds: const [],
        status: 'active',
      );
      return AdoptedLifeExperimentProgress(
        experiment: experiment,
        progress: _progress(experiment.id, completed: index),
      );
    });
    final repository = StubCandidatePlanningRepository(
      microSnapshot: _microSnapshot(count: 3, candidates: const []),
      activeActions: actions,
      activeExperiments: experiments,
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        providers: [Provider<int>.value(value: 0)],
        child: Scaffold(
          body: SingleChildScrollView(
            child: TodayAdoptedPlansSection(
              signals: const [],
              compatibilityAction: null,
              compatibilityExperiment: null,
              isBusy: false,
              repositoryOverride: repository,
              onActionFeedback: (_, __) async {},
              onOpenActionHub: () {},
              onOpenExperimentHub: () {},
              onOpenExperiment: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已采纳行动 1'), findsOneWidget);
    expect(find.text('已采纳行动 3'), findsOneWidget);
    expect(find.text('已采纳行动 4'), findsNothing);
    expect(find.text('已采纳实验 1'), findsOneWidget);
    expect(find.text('已采纳实验 3'), findsOneWidget);
    expect(find.text('已采纳实验 4'), findsNothing);
    expect(find.text('查看全部'), findsOneWidget);
    expect(find.textContaining('还有 1 项已采纳内容'), findsNWidgets(2));
    expect(find.text('来源已变化 · 已采纳内容继续保留'), findsOneWidget);
  });
}

CandidateSnapshot<MicroActionCandidateModel> _microSnapshot({
  required int count,
  required List<MicroActionCandidateModel> candidates,
}) {
  const start = '2026-07-12';
  return CandidateSnapshot(
    gate: CandidateGateState(
      kind: CandidateKind.microAction,
      periodStart: start,
      periodEnd: start,
      eligibleSignalCount: count,
      eligibleSignalCardIds: List.generate(count, (index) => 'signal-$index'),
    ),
    generation: CandidateGenerationState(
      kind: CandidateKind.microAction,
      periodStart: start,
      periodEnd: start,
      status: count >= 3
          ? CandidateGenerationStatus.ready
          : CandidateGenerationStatus.gated,
      eligibleSignalCount: count,
    ),
    candidates: candidates,
  );
}

CandidateSnapshot<ExperimentCandidateRecord> _experimentSnapshot({
  required int count,
  required List<ExperimentCandidateRecord> candidates,
}) {
  const start = '2026-07-06';
  const end = '2026-07-12';
  return CandidateSnapshot(
    gate: CandidateGateState(
      kind: CandidateKind.lifeExperiment,
      periodStart: start,
      periodEnd: end,
      eligibleSignalCount: count,
      eligibleSignalCardIds: List.generate(count, (index) => 'signal-$index'),
    ),
    generation: CandidateGenerationState(
      kind: CandidateKind.lifeExperiment,
      periodStart: start,
      periodEnd: end,
      status: count >= 3
          ? CandidateGenerationStatus.ready
          : CandidateGenerationStatus.gated,
      eligibleSignalCount: count,
    ),
    candidates: candidates,
  );
}

SevenDayProgressModel _progress(String subjectId, {required int completed}) {
  return SevenDayProgressModel(
    subjectId: subjectId,
    startDate: '2026-07-12',
    endDate: '2026-07-18',
    cells: List.generate(
      7,
      (index) => SevenDayProgressCell(
        localDate: '2026-07-${(12 + index).toString().padLeft(2, '0')}',
        state: index < completed
            ? ProgressCellState.completed
            : ProgressCellState.empty,
      ),
    ),
  );
}

class StubCandidatePlanningRepository extends LocalCandidatePlanningRepository {
  CandidateSnapshot<MicroActionCandidateModel> microSnapshot;
  CandidateSnapshot<ExperimentCandidateRecord>? experimentSnapshot;
  final List<AdoptedMicroActionProgress> activeActions;
  final List<AdoptedLifeExperimentProgress> activeExperiments;
  final List<String> adoptedMicroIds = [];
  final List<String> adoptedExperimentIds = [];

  StubCandidatePlanningRepository({
    required this.microSnapshot,
    this.experimentSnapshot,
    this.activeActions = const [],
    this.activeExperiments = const [],
  }) : super(
          localDatabase: LocalDatabase(
            dbPathOverride: 'candidate_hub_widget_stub.db',
          ),
          localCaptureRepository: LocalCaptureRepository(
            LocalDatabase(
              dbPathOverride: 'candidate_hub_capture_widget_stub.db',
            ),
          ),
          localLifeExperimentRepository: LocalLifeExperimentRepository(
            LocalDatabase(
              dbPathOverride: 'candidate_hub_experiment_widget_stub.db',
            ),
          ),
          localUserId: 'local',
        );

  @override
  Future<CandidateSnapshot<MicroActionCandidateModel>> dailyCandidateSnapshot(
    DateTime day,
  ) async {
    return microSnapshot;
  }

  @override
  Future<CandidateSnapshot<MicroActionCandidateModel>>
      refreshDailyWithGroundedSuggestions({
    required DateTime day,
    AppLanguage language = AppLanguage.simplifiedChinese,
    Duration debounce = Duration.zero,
  }) async {
    return microSnapshot;
  }

  @override
  Stream<CandidateGenerationState> watchGenerationState({
    required CandidateKind kind,
    required String periodStart,
    required String periodEnd,
  }) {
    return Stream.value(
      kind == CandidateKind.microAction
          ? microSnapshot.generation
          : experimentSnapshot!.generation,
    );
  }

  @override
  Future<List<MicroActionModel>> adoptMicroActionCandidates(
    Iterable<String> candidateIds,
  ) async {
    adoptedMicroIds.addAll(candidateIds);
    return const [];
  }

  @override
  Future<List<AdoptedMicroActionProgress>> listActiveMicroActionsForDate(
    DateTime day,
  ) async {
    return activeActions;
  }

  @override
  Future<List<AdoptedLifeExperimentProgress>> listActiveExperimentsForDate(
    DateTime day,
  ) async {
    return activeExperiments;
  }

  @override
  Future<CandidateGateState> dailyGate(DateTime day) async {
    return microSnapshot.gate;
  }

  @override
  Future<CandidateGateState> weeklyGate(DateTime day) async {
    return experimentSnapshot?.gate ??
        CandidateGateState(
          kind: CandidateKind.lifeExperiment,
          periodStart: '2026-07-06',
          periodEnd: '2026-07-12',
          eligibleSignalCount: microSnapshot.gate.eligibleSignalCount,
        );
  }

  @override
  Future<CandidateSnapshot<ExperimentCandidateRecord>> weeklyCandidateSnapshot(
      DateTime day) async {
    return experimentSnapshot!;
  }

  @override
  Future<CandidateSnapshot<ExperimentCandidateRecord>>
      refreshWeeklyWithGroundedSuggestions({
    required DateTime day,
    AppLanguage language = AppLanguage.simplifiedChinese,
    Duration debounce = Duration.zero,
  }) async {
    return experimentSnapshot!;
  }

  @override
  Future<List<LifeExperimentModel>> adoptExperimentCandidates(
    Iterable<String> candidateIds,
  ) async {
    adoptedExperimentIds.addAll(candidateIds);
    return const [];
  }
}
