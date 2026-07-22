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
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  testWidgets('小实验候选页在不足三条时解释门槛且不伪造候选', (tester) async {
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
    expect(find.text('生活小实验 · 小实验'), findsOneWidget);
    expect(find.textContaining('现在就能开始'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('candidate-hub-experiment-pattern')),
      findsOneWidget,
    );
    expect(find.byType(AuroraExperimentHeroPattern), findsOneWidget);
    expect(find.byType(AuroraSignalHeroPattern), findsNothing);
    expect(find.byType(AuroraHeroEmblem), findsNothing);
    expect(
        find.byKey(const ValueKey('candidate-adopt-selected')), findsNothing);
    expect(repository.adoptedMicroIds, isEmpty);
  });

  testWidgets('小实验候选页最多显示三个并允许一次采纳多个', (tester) async {
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
    expect(find.text('已选择 2 项'), findsOneWidget);
    expect(find.text('采纳'), findsOneWidget);
    expect(find.text('考虑/观察'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('candidate-adopt-none')),
      findsNothing,
    );

    final adoptButton = find.byKey(const ValueKey('candidate-adopt-selected'));
    await tester.ensureVisible(adoptButton);
    await tester.tap(adoptButton);
    await tester.pumpAndSettle();
    expect(repository.adoptedMicroIds,
        containsAll(<String>['candidate-1', 'candidate-2']));
    expect(repository.adoptedMicroIds, hasLength(2));
  });

  testWidgets('候选页把考虑观察保存为第二个明确决定且不创建计划', (tester) async {
    const candidate = MicroActionCandidateModel(
      id: 'candidate-consider',
      candidateGroupId: 'group-consider',
      localUserId: 'local',
      localDate: '2026-07-12',
      rank: 1,
      title: '先观察一次切换后的恢复',
      reason: '来自三条符合条件的真实 Signal。',
      difficulty: 'very_light',
      linkedSignalCardIds: ['signal-1', 'signal-2', 'signal-3'],
      focusDomainIds: [],
      status: 'generated',
      sourceHash: 'source-consider',
    );
    final repository = StubCandidatePlanningRepository(
      microSnapshot: _microSnapshot(
        count: 3,
        candidates: const [candidate],
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
          kind: CandidateKind.microAction,
          repositoryOverride: repository,
          nowLoader: () => DateTime(2026, 7, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final checkbox = find.descendant(
      of: find.byKey(
        const ValueKey('candidate-option-candidate-consider'),
      ),
      matching: find.byType(Checkbox),
    );
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pump();

    final consider = find.byKey(const ValueKey('candidate-consider-selected'));
    await tester.ensureVisible(consider);
    await tester.tap(consider);
    await tester.pumpAndSettle();

    expect(repository.consideredCandidateIds, ['candidate-consider']);
    expect(repository.adoptedMicroIds, isEmpty);
    expect(find.textContaining('不会创建计划或进度'), findsOneWidget);
  });

  testWidgets('候选编辑与小实验登记在 390x844 使用 Aurora 弹层且可关闭', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const candidate = MicroActionCandidateModel(
      id: 'candidate-modal',
      candidateGroupId: 'group-modal',
      localUserId: 'local',
      localDate: '2026-07-12',
      rank: 1,
      title: '留出十分钟缓冲',
      reason: '来自三条符合条件的真实信号。',
      difficulty: 'very_light',
      linkedSignalCardIds: ['signal-1', 'signal-2', 'signal-3'],
      focusDomainIds: [],
      status: 'generated',
      sourceHash: 'source-modal',
    );
    const action = MicroActionModel(
      id: 'active-modal',
      judgementId: '',
      title: '先放慢一件事',
      reason: '看看今天的真实进度。',
      status: 'active',
    );
    final repository = StubCandidatePlanningRepository(
      microSnapshot: _microSnapshot(count: 3, candidates: const [candidate]),
      activeActions: [
        AdoptedMicroActionProgress(
          action: action,
          progress: _progress(action.id, completed: 0),
        ),
      ],
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

    final todayCell = find.byKey(const ValueKey('progress-cell-2026-07-12'));
    expect(
      find.byKey(
        const ValueKey('candidate-daily-completion-hint-active-modal'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('是否试了'), findsOneWidget);
    expect(find.textContaining('已完成'), findsNothing);
    expect(find.textContaining('未完成'), findsNothing);
    await tester.ensureVisible(todayCell);
    await tester.tap(todayCell);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('small-try-feedback-sheet')),
      findsOneWidget,
    );
    expect(find.text('试了'), findsOneWidget);
    expect(find.text('这次没试'), findsOneWidget);
    expect(find.text('已完成'), findsNothing);
    expect(find.text('未完成'), findsNothing);
    expect(find.text('发生了'), findsNothing);
    expect(find.text('没发生'), findsNothing);
    expect(find.text('今天不适合'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    final editButton = find.byIcon(Icons.edit_outlined);
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('candidate-edit-aurora-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('candidate-edit-title')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('candidate-edit-aurora-dialog')),
      findsNothing,
    );
  });

  testWidgets('不足三条 Signal 时仍可决定是否把进行中目标延续到下周', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const experiment = LifeExperimentModel(
      id: 'active-experiment-feedback',
      localUserId: 'local',
      sourceWeekStart: '2026-07-13',
      sourceWeekEnd: '2026-07-19',
      title: '晚间留十分钟低要求恢复',
      hypothesis: '减少晚间继续硬撑。',
      suggestedAction: '每天试一次。',
      linkedSignalCardIds: [],
      status: 'active',
    );
    final repository = StubCandidatePlanningRepository(
      microSnapshot: _microSnapshot(count: 3, candidates: const []),
      experimentSnapshot: _experimentSnapshot(
        count: 2,
        candidates: const [],
        start: '2026-07-13',
        end: '2026-07-19',
      ),
      continuableExperiments: [
        AdoptedLifeExperimentProgress(
          experiment: experiment,
          progress: _progress(experiment.id, completed: 0),
        ),
      ],
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
          nowLoader: () => DateTime(2026, 7, 17),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('下周尝试'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('candidate-hub-review-pattern')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('candidate-hub-review-pattern')),
        matching: find.byType(AuroraReviewHeroPattern),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('candidate-hub-signal-pattern')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('candidate-hub-experiment-pattern')),
      findsNothing,
    );
    expect(find.byType(AuroraExperimentHeroPattern), findsNothing);
    expect(find.byType(AuroraSignalHeroPattern), findsNothing);
    expect(find.byType(AuroraHeroEmblem), findsNothing);
    expect(find.textContaining('7月20日'), findsOneWidget);
    expect(find.textContaining('7月26日'), findsOneWidget);
    expect(find.text('进行中的目标'), findsOneWidget);
    expect(find.text('晚间留十分钟低要求恢复'), findsOneWidget);
    expect(find.text('记录 3 条信号后开始显示'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('已采纳与实际进度'), findsNothing);
    expect(
        find.byKey(const ValueKey('progress-cell-2026-07-12')), findsNothing);

    final continuationCheckbox = find.descendant(
      of: find.byKey(
        const ValueKey('continuation-option-active-experiment-feedback'),
      ),
      matching: find.byType(Checkbox),
    );
    await tester.ensureVisible(continuationCheckbox);
    await tester.tap(continuationCheckbox);
    await tester.pump();
    expect(find.text('已选择 1 项'), findsOneWidget);

    final confirm = find.byKey(const ValueKey('candidate-adopt-selected'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(repository.continuedExperimentIds, ['active-experiment-feedback']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('下周页显示进行中续行与三条 AI 提案并可一起确认', (tester) async {
    final candidates = List.generate(
      4,
      (index) => ExperimentCandidateRecord(
        id: 'experiment-candidate-${index + 1}',
        candidateGroupId: 'experiment-group-1',
        localUserId: 'local',
        weekStart: '2026-07-13',
        weekEnd: '2026-07-19',
        rank: index + 1,
        title: '候选目标 ${index + 1}',
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
        start: '2026-07-13',
        end: '2026-07-19',
      ),
      continuableExperiments: [
        AdoptedLifeExperimentProgress(
          experiment: const LifeExperimentModel(
            id: 'active-experiment-combined',
            localUserId: 'local',
            sourceWeekStart: '2026-07-13',
            sourceWeekEnd: '2026-07-19',
            title: '本周正在做的恢复目标',
            hypothesis: '短暂恢复可能有效。',
            suggestedAction: '午后离开屏幕十分钟。',
            linkedSignalCardIds: [],
            status: 'active',
          ),
          progress: _progress('active-experiment-combined', completed: 2),
        ),
      ],
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
          nowLoader: () => DateTime(2026, 7, 17),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('下周尝试'), findsOneWidget);
    expect(find.text('进行中的目标'), findsOneWidget);
    expect(find.text('目标提案'), findsNWidgets(2));
    expect(find.text('七日目标'), findsNWidgets(3));

    expect(find.text('候选目标 1'), findsOneWidget);
    expect(find.text('候选目标 3'), findsOneWidget);
    expect(find.text('候选目标 4'), findsNothing);
    expect(find.text('最多 3 个候选'), findsNothing);
    expect(find.text('可采纳 0–3 个'), findsNothing);

    final continuationCheckbox = find.descendant(
      of: find.byKey(
        const ValueKey('continuation-option-active-experiment-combined'),
      ),
      matching: find.byType(Checkbox),
    );
    await tester.ensureVisible(continuationCheckbox);
    await tester.tap(continuationCheckbox);
    await tester.pump();

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
    expect(find.text('已选择 3 项'), findsOneWidget);
    await tester.ensureVisible(adoptButton);
    await tester.tap(adoptButton);
    await tester.pumpAndSettle();

    expect(
      repository.adoptedExperimentIds,
      ['experiment-candidate-1', 'experiment-candidate-3'],
    );
    expect(
      repository.continuedExperimentIds,
      ['active-experiment-combined'],
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
        title: '已采纳目标 ${index + 1}',
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
              onExperimentFeedback: (_, __) async {},
              onOpenAll: () {},
              onOpenActionHub: () {},
              onOpenExperimentHub: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已采纳行动 1'), findsOneWidget);
    expect(find.text('已采纳行动 3'), findsOneWidget);
    expect(find.text('已采纳行动 4'), findsNothing);
    expect(find.text('已采纳目标 1'), findsOneWidget);
    expect(find.text('已采纳目标 3'), findsOneWidget);
    expect(find.text('已采纳目标 4'), findsNothing);
    expect(find.text('查看全部'), findsOneWidget);
    expect(find.textContaining('还有 1 项已采纳内容'), findsNWidgets(2));
    expect(find.text('来源已变化 · 已采纳内容继续保留'), findsOneWidget);
  });

  testWidgets('Today 小实验与目标按各自模型提交 canonical 完成状态', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const action = MicroActionModel(
      id: 'active-action-completion',
      judgementId: '',
      title: '任务切换前留两分钟缓冲',
      reason: '最近的切换比较密集。',
      status: 'active',
    );
    const experiment = LifeExperimentModel(
      id: 'active-experiment-completion',
      localUserId: 'local',
      sourceWeekStart: '2026-07-06',
      sourceWeekEnd: '2026-07-12',
      title: '午后留十分钟低要求恢复',
      hypothesis: '短暂留白可能让切换更轻一点。',
      suggestedAction: '午后离开屏幕十分钟。',
      linkedSignalCardIds: [],
      status: 'active',
    );
    final repository = StubCandidatePlanningRepository(
      microSnapshot: _microSnapshot(count: 3, candidates: const []),
      activeActions: [
        AdoptedMicroActionProgress(
          action: action,
          progress: _progress(action.id, completed: 0),
        ),
      ],
      activeExperiments: [
        AdoptedLifeExperimentProgress(
          experiment: experiment,
          progress: _progress(experiment.id, completed: 0),
        ),
      ],
    );
    final submittedActions =
        <({String completionStatus, String? effect, String? difficulty})>[];
    final submittedExperiments = <String>[];

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
              onActionFeedback: (_, feedback) async {
                submittedActions.add((
                  completionStatus: feedback.completionStatus,
                  effect: feedback.effect,
                  difficulty: feedback.difficulty,
                ));
              },
              onExperimentFeedback: (_, feedback) async {
                submittedExperiments.add(feedback);
              },
              onOpenAll: () {},
              onOpenActionHub: () {},
              onOpenExperimentHub: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('小实验'), findsOneWidget);
    expect(find.text('目标'), findsOneWidget);
    expect(find.text('登记一次'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('未完成'), findsOneWidget);
    expect(find.text('发生了'), findsNothing);
    expect(find.text('没发生'), findsNothing);
    expect(find.text('今天不适合'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('today-adopted-experiments')),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsNothing,
    );

    await tester.tap(find.text('登记一次'));
    await tester.pumpAndSettle();
    expect(find.text('登记这次小实验'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('small-try-completed-choice')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('small-try-effect-helpful')),
    );
    await tester.tap(
      find.byKey(const ValueKey('small-try-difficulty-easy')),
    );
    await tester.pumpAndSettle();
    final completedSave = find.byKey(const ValueKey('small-try-feedback-save'));
    await tester.ensureVisible(completedSave);
    await tester.pumpAndSettle();
    await tester.tap(completedSave);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('small-try-feedback-sheet')),
      findsNothing,
    );

    final recordAgain = find.text('登记一次');
    await tester.ensureVisible(recordAgain);
    await tester.tap(recordAgain);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('small-try-not-completed-choice')),
    );
    final notCompletedSave =
        find.byKey(const ValueKey('small-try-feedback-save'));
    await tester.ensureVisible(notCompletedSave);
    await tester.pumpAndSettle();
    await tester.tap(notCompletedSave);
    await tester.pumpAndSettle();

    final completedGoal = find.text('已完成');
    await tester.ensureVisible(completedGoal);
    await tester.tap(completedGoal);
    await tester.pumpAndSettle();
    final notCompletedGoal = find.text('未完成');
    await tester.ensureVisible(notCompletedGoal);
    await tester.tap(notCompletedGoal);
    await tester.pumpAndSettle();

    expect(submittedActions, [
      (
        completionStatus: 'completed',
        effect: 'helpful',
        difficulty: 'easy',
      ),
      (
        completionStatus: 'not_completed',
        effect: null,
        difficulty: null,
      ),
    ]);
    expect(submittedExperiments, ['completed', 'not_completed']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('今日尝试的查看全部直接打开统一生活小实验页', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = StubCandidatePlanningRepository(
      microSnapshot: _microSnapshot(count: 3, candidates: const []),
    );
    var bottomNavigationTapCount = 0;
    var actionHubOpenCount = 0;
    var goalHubOpenCount = 0;
    var allAttemptsOpenCount = 0;

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        providers: [Provider<int>.value(value: 0)],
        child: Scaffold(
          body: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => SingleChildScrollView(
                child: TodayAdoptedPlansSection(
                  signals: const [],
                  compatibilityAction: null,
                  compatibilityExperiment: null,
                  isBusy: false,
                  repositoryOverride: repository,
                  onActionFeedback: (_, __) async {},
                  onExperimentFeedback: (_, __) async {},
                  onOpenAll: () => allAttemptsOpenCount += 1,
                  onOpenActionHub: () => actionHubOpenCount += 1,
                  onOpenExperimentHub: () => goalHubOpenCount += 1,
                ),
              ),
            ),
          ),
          bottomNavigationBar: SizedBox(
            height: 88,
            child: TextButton(
              key: const ValueKey('fake-shell-bottom-navigation'),
              onPressed: () => bottomNavigationTapCount += 1,
              child: const Text('底部导航'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看全部'));
    await tester.pumpAndSettle();

    expect(allAttemptsOpenCount, 1);
    expect(actionHubOpenCount, 0);
    expect(bottomNavigationTapCount, 0);
    expect(
      find.byKey(const ValueKey('today-attempts-all-sheet')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('today-open-small-try-candidates')),
    );
    await tester.tap(
      find.byKey(const ValueKey('today-open-goal-candidates')),
    );
    await tester.pumpAndSettle();
    expect(actionHubOpenCount, 1);
    expect(goalHubOpenCount, 1);
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
  String start = '2026-07-06',
  String end = '2026-07-12',
}) {
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
  List<AdoptedLifeExperimentProgress> continuableExperiments;
  final List<String> adoptedMicroIds = [];
  final List<String> adoptedExperimentIds = [];
  final List<String> continuedExperimentIds = [];
  final List<String> consideredCandidateIds = [];

  StubCandidatePlanningRepository({
    required this.microSnapshot,
    this.experimentSnapshot,
    this.activeActions = const [],
    this.activeExperiments = const [],
    this.continuableExperiments = const [],
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
  Future<NextWeekPlanCandidateSnapshot>
      refreshNextWeekPlanWithGroundedSuggestions({
    required DateTime day,
    AppLanguage language = AppLanguage.simplifiedChinese,
  }) {
    return nextWeekPlanCandidateSnapshot(day);
  }

  @override
  Future<NextWeekPlanCandidateSnapshot> nextWeekPlanCandidateSnapshot(
    DateTime day,
  ) async {
    final weekly = experimentSnapshot!;
    final start =
        DateTime(day.year, day.month, day.day).add(const Duration(days: 7));
    return NextWeekPlanCandidateSnapshot(
      gate: weekly.gate,
      targetWeekStart:
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
      targetWeekEnd: '',
      smallTryCandidates: microSnapshot.candidates,
      goalCandidates: weekly.candidates.take(3).toList(growable: false),
    );
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
  Future<int> markCandidatesConsidering(
    Iterable<String> candidateIds,
  ) async {
    final ids = candidateIds.toList(growable: false);
    consideredCandidateIds.addAll(ids);
    return ids.length;
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
  Future<List<AdoptedLifeExperimentProgress>>
      listContinuableExperimentsForNextWeek(DateTime day) async {
    return continuableExperiments;
  }

  @override
  Future<List<LifeExperimentModel>> continueExperimentsForNextWeek({
    required Iterable<String> experimentIds,
    required DateTime day,
  }) async {
    final selected = experimentIds.toList(growable: false);
    continuedExperimentIds.addAll(selected);
    continuableExperiments = continuableExperiments
        .where((item) => !selected.contains(item.experiment.id))
        .toList(growable: false);
    return const [];
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
