import 'package:ai_opportunity_radar/core/models/candidate_models.dart';
import 'package:ai_opportunity_radar/core/models/experiment_creation_source.dart';
import 'package:ai_opportunity_radar/core/models/experiment_evaluation_models.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/experiment/experiment_action_preference_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildExperimentActionPreferenceReport', () {
    test('未尝试、无明确效果和无效反馈均不进入行动偏好', () {
      final smallExperiment = _smallExperiment(
        id: 'small-1',
        title: '任务切换前停两分钟',
        completedCells: 4,
      );

      final report = buildExperimentActionPreferenceReport(
        smallExperiments: [smallExperiment],
        smallExperimentFeedbacks: {
          'small-1': [
            _smallFeedback(
              id: 'not-tried',
              itemId: 'small-1',
              localDate: '2026-07-20',
              happened: 'not_completed',
              effect: SmallTryEffect.helpful,
            ),
            _smallFeedback(
              id: 'unclear',
              itemId: 'small-1',
              localDate: '2026-07-21',
              happened: 'completed',
              effect: 'unclear',
            ),
            _smallFeedback(
              id: 'invalid',
              itemId: 'small-1',
              localDate: '2026-07-22',
              happened: 'completed',
              effect: SmallTryEffect.helpful,
              isValid: false,
            ),
          ],
        },
        goals: const [],
        goalReviews: const {},
      );

      // Four completed progress cells alone must not become "effective".
      expect(smallExperiment.progress.completedAttempts, 4);
      expect(report.totalEvaluatedFeedbackCount, 0);
      expect(report.smallExperimentFeedbackCount, 0);
      expect(report.positiveCount, 0);
      expect(report.distinctItemCount, 0);
      expect(report.themes, isEmpty);
      expect(report.hasPreferenceSynthesis, isFalse);
    });

    test('小实验效果与目标周次和整体结果分轨计数', () {
      final smallExperiment = _smallExperiment(
        id: 'small-1',
        title: '任务切换前停两分钟',
      );
      final goal = _goal(
        id: 'goal-1',
        title: '连续观察午后恢复',
      );

      final report = buildExperimentActionPreferenceReport(
        smallExperiments: [smallExperiment],
        smallExperimentFeedbacks: {
          'small-1': [
            _smallFeedback(
              id: 'small-helpful',
              itemId: 'small-1',
              localDate: '2026-07-20',
              happened: 'completed',
              effect: SmallTryEffect.helpful,
              difficulty: SmallTryDifficulty.easy,
            ),
            _smallFeedback(
              id: 'small-no-effect',
              itemId: 'small-1',
              localDate: '2026-07-21',
              happened: 'completed',
              effect: SmallTryEffect.noEffect,
              difficulty: SmallTryDifficulty.difficult,
            ),
          ],
        },
        goals: [goal],
        goalReviews: {
          'goal-1': [
            _goalReview(
              id: 'goal-weekly',
              itemId: 'goal-1',
              localDate: '2026-07-22',
              outcomeResult: GoalOutcomeResult.improved,
              reviewType: GoalReviewType.weekly,
              burden: EvaluationEffort.easy,
            ),
            _goalReview(
              id: 'goal-whole-round',
              itemId: 'goal-1',
              localDate: '2026-07-23',
              outcomeResult: GoalOutcomeResult.noChange,
              reviewType: GoalReviewType.wholeRound,
              burden: EvaluationEffort.tooDifficult,
            ),
            _goalReview(
              id: 'goal-unclear',
              itemId: 'goal-1',
              localDate: '2026-07-24',
              outcomeResult: GoalOutcomeResult.unclear,
              reviewType: GoalReviewType.weekly,
              burden: EvaluationEffort.acceptable,
            ),
          ],
        },
      );

      expect(report.smallExperimentFeedbackCount, 2);
      expect(report.goalReviewCount, 2);
      expect(report.totalEvaluatedFeedbackCount, 4);
      expect(report.distinctItemCount, 2);
      expect(report.distinctDayCount, 4);
      expect(report.positiveCount, 2);
      expect(report.partialPositiveCount, 0);
      expect(report.neutralOrNegativeCount, 2);
      expect(report.easyCount, 2);
      expect(report.acceptableCount, 0);
      expect(report.difficultCount, 2);
    });

    test('繁體行動文案仍會分類為恢復與緩衝', () {
      final smallExperiment = _smallExperiment(
        id: 'traditional-recovery',
        title: '任務切換前留兩分鐘緩衝',
      );

      final report = buildExperimentActionPreferenceReport(
        smallExperiments: [smallExperiment],
        smallExperimentFeedbacks: {
          'traditional-recovery': [
            _smallFeedback(
              id: 'traditional-recovery-feedback',
              itemId: 'traditional-recovery',
              localDate: '2026-07-31',
            ),
          ],
        },
        goals: const [],
        goalReviews: const {},
      );

      expect(report.themes, hasLength(1));
      expect(
        report.themes.single.theme,
        ExperimentActionTheme.recoveryAndBuffer,
      );
    });

    test('五条明确反馈覆盖两项和三个登记日后才形成偏好总结', () {
      final smallExperiment = _smallExperiment(
        id: 'small-1',
        title: '任务切换前停两分钟',
      );
      final goal = _goal(
        id: 'goal-1',
        title: '连续观察午后恢复',
      );

      final readyReport = buildExperimentActionPreferenceReport(
        smallExperiments: [smallExperiment],
        smallExperimentFeedbacks: {
          'small-1': [
            _smallFeedback(
              id: 'small-1-a',
              itemId: 'small-1',
              localDate: '2026-07-20',
              effect: SmallTryEffect.helpful,
            ),
            _smallFeedback(
              id: 'small-1-b',
              itemId: 'small-1',
              localDate: '2026-07-21',
              effect: SmallTryEffect.somewhatHelpful,
            ),
            _smallFeedback(
              id: 'small-1-c',
              itemId: 'small-1',
              localDate: '2026-07-22',
              effect: SmallTryEffect.noEffect,
            ),
          ],
        },
        goals: [goal],
        goalReviews: {
          'goal-1': [
            _goalReview(
              id: 'goal-1-a',
              itemId: 'goal-1',
              localDate: '2026-07-20',
              outcomeResult: GoalOutcomeResult.improved,
            ),
            _goalReview(
              id: 'goal-1-b',
              itemId: 'goal-1',
              localDate: '2026-07-21',
              outcomeResult: GoalOutcomeResult.somewhatImproved,
            ),
          ],
        },
      );

      expect(readyReport.totalEvaluatedFeedbackCount, 5);
      expect(readyReport.distinctItemCount, 2);
      expect(readyReport.distinctDayCount, 3);
      expect(readyReport.hasPreferenceSynthesis, isTrue);
      expect(readyReport.remainingFeedbackCount, 0);
      expect(readyReport.remainingItemCount, 0);
      expect(readyReport.remainingDayCount, 0);

      final tooFewDays = buildExperimentActionPreferenceReport(
        smallExperiments: [smallExperiment],
        smallExperimentFeedbacks: {
          'small-1': List.generate(
            3,
            (index) => _smallFeedback(
              id: 'same-day-small-$index',
              itemId: 'small-1',
              localDate: '2026-07-20',
              effect: SmallTryEffect.helpful,
            ),
          ),
        },
        goals: [goal],
        goalReviews: {
          'goal-1': List.generate(
            2,
            (index) => _goalReview(
              id: 'same-day-goal-$index',
              itemId: 'goal-1',
              localDate: '2026-07-21',
              outcomeResult: GoalOutcomeResult.improved,
            ),
          ),
        },
      );

      expect(tooFewDays.totalEvaluatedFeedbackCount, 5);
      expect(tooFewDays.distinctItemCount, 2);
      expect(tooFewDays.distinctDayCount, 2);
      expect(tooFewDays.hasPreferenceSynthesis, isFalse);
      expect(tooFewDays.remainingDayCount, 1);
    });

    test('十条反馈覆盖三项且至少两个主题后才允许条件比较', () {
      final recovery = _smallExperiment(
        id: 'recovery',
        title: '离屏休息两分钟',
      );
      final switching = _smallExperiment(
        id: 'switching',
        title: '任务切换前停两分钟',
      );
      final switchingGoal = _goal(
        id: 'switching-goal',
        title: '连续观察会议切换后的负担',
      );

      final comparable = buildExperimentActionPreferenceReport(
        smallExperiments: [recovery, switching],
        smallExperimentFeedbacks: {
          'recovery': List.generate(
            4,
            (index) => _smallFeedback(
              id: 'recovery-$index',
              itemId: 'recovery',
              localDate: '2026-07-${20 + index}',
              effect: SmallTryEffect.helpful,
            ),
          ),
          'switching': List.generate(
            3,
            (index) => _smallFeedback(
              id: 'switching-$index',
              itemId: 'switching',
              localDate: '2026-07-${20 + index}',
              effect: SmallTryEffect.somewhatHelpful,
            ),
          ),
        },
        goals: [switchingGoal],
        goalReviews: {
          'switching-goal': List.generate(
            3,
            (index) => _goalReview(
              id: 'switching-goal-$index',
              itemId: 'switching-goal',
              localDate: '2026-07-${23 + index}',
              outcomeResult: GoalOutcomeResult.improved,
            ),
          ),
        },
      );

      expect(comparable.totalEvaluatedFeedbackCount, 10);
      expect(comparable.distinctItemCount, 3);
      expect(
        comparable.themes
            .where((theme) => theme.evaluatedFeedbackCount >= 2)
            .length,
        2,
      );
      expect(comparable.canCompareConditions, isTrue);

      final singleTheme = buildExperimentActionPreferenceReport(
        smallExperiments: [
          _smallExperiment(id: 'rest-1', title: '休息一分钟'),
          _smallExperiment(id: 'rest-2', title: '离屏休息两分钟'),
        ],
        smallExperimentFeedbacks: {
          'rest-1': List.generate(
            4,
            (index) => _smallFeedback(
              id: 'rest-1-$index',
              itemId: 'rest-1',
              localDate: '2026-07-${20 + index}',
              effect: SmallTryEffect.helpful,
            ),
          ),
          'rest-2': List.generate(
            3,
            (index) => _smallFeedback(
              id: 'rest-2-$index',
              itemId: 'rest-2',
              localDate: '2026-07-${20 + index}',
              effect: SmallTryEffect.somewhatHelpful,
            ),
          ),
        },
        goals: [
          _goal(id: 'rest-goal', title: '连续观察休息后的恢复'),
        ],
        goalReviews: {
          'rest-goal': List.generate(
            3,
            (index) => _goalReview(
              id: 'rest-goal-$index',
              itemId: 'rest-goal',
              localDate: '2026-07-${23 + index}',
              outcomeResult: GoalOutcomeResult.improved,
            ),
          ),
        },
      );

      expect(singleTheme.totalEvaluatedFeedbackCount, 10);
      expect(singleTheme.distinctItemCount, 3);
      expect(singleTheme.themes, hasLength(1));
      expect(singleTheme.canCompareConditions, isFalse);
    });
  });

  testWidgets('专业版入口和行动偏好报告关键区域可见', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExperimentActionPreferenceEntryCard(
            isPremium: true,
            isLoading: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey('experiment-pro-action-preference-entry'),
      ),
      findsOneWidget,
    );
    expect(find.text('Action preferences'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const ValueKey('experiment-pro-action-preference-entry'),
      ),
    );
    expect(tapped, isTrue);

    const report = ExperimentActionPreferenceReport(
      totalEvaluatedFeedbackCount: 10,
      distinctItemCount: 3,
      distinctDayCount: 5,
      smallExperimentFeedbackCount: 6,
      goalReviewCount: 4,
      positiveCount: 5,
      partialPositiveCount: 3,
      neutralOrNegativeCount: 2,
      easyCount: 4,
      acceptableCount: 4,
      difficultCount: 2,
      userCreatedFeedbackCount: 4,
      suggestedFeedbackCount: 6,
      themes: [
        ExperimentActionThemeSummary(
          theme: ExperimentActionTheme.recoveryAndBuffer,
          evaluatedFeedbackCount: 6,
          positiveFeedbackCount: 5,
          manageableFeedbackCount: 5,
          distinctItemCount: 2,
        ),
        ExperimentActionThemeSummary(
          theme: ExperimentActionTheme.startingAndSwitching,
          evaluatedFeedbackCount: 4,
          positiveFeedbackCount: 3,
          manageableFeedbackCount: 3,
          distinctItemCount: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: ExperimentActionPreferenceReportPage(report: report),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey('experiment-pro-action-preference-page'),
      ),
      findsOneWidget,
    );
    final reportHero =
        find.byKey(const ValueKey('experiment-action-preference-hero'));
    final reportBack =
        find.byKey(const ValueKey('experiment-action-preference-back'));
    expect(reportHero, findsOneWidget);
    expect(reportBack, findsOneWidget);
    final reportBackRect = tester.getRect(reportBack);
    final reportTitleRect =
        tester.getRect(find.text('Action preference report'));
    expect(reportBackRect.top, lessThan(reportTitleRect.bottom));
    expect(reportBackRect.bottom, greaterThan(reportTitleRect.top));
    expect(
      tester.getBottomLeft(reportHero).dy -
          tester
              .getBottomLeft(find.textContaining('A cross-experiment view'))
              .dy,
      lessThanOrEqualTo(21),
    );
    expect(
      find.byKey(const ValueKey('experiment-preference-readiness')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('experiment-preference-effect-chart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('experiment-preference-effort-chart')),
      findsOneWidget,
    );
    expect(find.text('Action preference report'), findsOneWidget);
    expect(find.text('What seems more helpful'), findsOneWidget);
    expect(find.text('How to read this report'), findsOneWidget);
    expect(
      find.textContaining('Completion alone never counts as effectiveness'),
      findsOneWidget,
    );
  });
}

AdoptedMicroActionProgress _smallExperiment({
  required String id,
  required String title,
  int completedCells = 0,
  ExperimentCreationSource source = ExperimentCreationSource.userCreated,
}) {
  return AdoptedMicroActionProgress(
    action: MicroActionModel(
      id: id,
      judgementId: '',
      title: title,
      reason: '用于行动偏好测试',
      status: 'active',
      creationSource: source,
    ),
    progress: SevenDayProgressModel(
      subjectId: id,
      startDate: '2026-07-20',
      endDate: '2026-07-26',
      cells: List.generate(
        completedCells,
        (index) => SevenDayProgressCell(
          localDate: '2026-07-${20 + index}',
          state: ProgressCellState.completed,
        ),
      ),
    ),
  );
}

MicroActionFeedbackModel _smallFeedback({
  required String id,
  required String itemId,
  required String localDate,
  String happened = 'completed',
  String effect = SmallTryEffect.helpful,
  String difficulty = SmallTryDifficulty.easy,
  bool isValid = true,
}) {
  return MicroActionFeedbackModel(
    id: id,
    microActionId: itemId,
    localDate: localDate,
    happened: happened,
    effect: effect,
    difficulty: difficulty,
    isValid: isValid,
  );
}

LifeExperimentModel _goal({
  required String id,
  required String title,
  ExperimentCreationSource source = ExperimentCreationSource.userCreated,
}) {
  return LifeExperimentModel(
    id: id,
    localUserId: 'local',
    sourceWeekStart: '2026-07-20',
    sourceWeekEnd: '2026-07-26',
    title: title,
    hypothesis: '用于行动偏好测试',
    suggestedAction: '连续观察并登记总结',
    linkedSignalCardIds: const [],
    status: 'active',
    creationSource: source,
  );
}

LifeExperimentOutcomeReviewModel _goalReview({
  required String id,
  required String itemId,
  required String localDate,
  required String outcomeResult,
  String reviewType = GoalReviewType.weekly,
  String burden = EvaluationEffort.acceptable,
}) {
  final reviewedAt = DateTime.parse('${localDate}T12:00:00Z');
  return LifeExperimentOutcomeReviewModel(
    id: id,
    experimentId: itemId,
    localUserId: 'local',
    reviewedAt: reviewedAt,
    localDate: localDate,
    outcomeResult: outcomeResult,
    reviewType: reviewType,
    burden: burden,
    completedDaysAtReview: 3,
    minimumObservationDays: 3,
    createdAt: reviewedAt,
  );
}
