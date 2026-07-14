import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/candidate_models.dart';
import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/shared/widgets/candidate_planning_widgets.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  testWidgets('三信号门槛显示真实进度和避免过度解读说明', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        providers: [Provider<int>.value(value: 0)],
        child: const Scaffold(
          body: CandidateGateCard(
            gate: CandidateGateState(
              kind: CandidateKind.microAction,
              periodStart: '2026-07-12',
              periodEnd: '2026-07-12',
              eligibleSignalCount: 2,
            ),
            icon: Icons.spa_rounded,
            accent: Colors.purple,
          ),
        ),
      ),
    );

    expect(find.text('记录 3 条信号后开始显示'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.textContaining('避免把某一个瞬间过度解读'), findsOneWidget);
    expect(find.textContaining('草稿和未确认的 AI 内容不会计入'), findsOneWidget);
  });

  testWidgets('候选卡用文字与图标表达选择状态并可展开依据', (tester) async {
    bool? selected;
    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        providers: [Provider<int>.value(value: 0)],
        child: Scaffold(
          body: CandidateOptionCard(
            id: 'cand-1',
            rank: 1,
            title: '午后先离开屏幕两分钟',
            reason: '最近三条真实信号都提到午后切换后很难恢复。',
            difficultyLabel: '很轻',
            evidenceCount: 3,
            selected: false,
            adopted: false,
            disabled: false,
            sourceChanged: false,
            energyCapacityBand: EnergyCapacityBand.low,
            energyAdaptationExplanation: '能量适配：保持短时、少切换，并多留一点缓冲。',
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('3 条信号依据'), findsOneWidget);
    expect(find.text('未选择'), findsOneWidget);
    expect(find.byKey(const ValueKey('candidate-energy-adaptation-cand-1')),
        findsOneWidget);
    expect(find.textContaining('少切换'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(selected, isTrue);

    await tester.tap(find.text('为什么看到这个'));
    await tester.pumpAndSettle();
    expect(find.text('最近三条真实信号都提到午后切换后很难恢复。'), findsOneWidget);
  });

  testWidgets('七日进度格同时用勾叉空心图标表达状态且点击区域至少44点', (tester) async {
    SevenDayProgressCell? tapped;
    const cells = [
      SevenDayProgressCell(
        localDate: '2026-07-12',
        state: ProgressCellState.completed,
      ),
      SevenDayProgressCell(
        localDate: '2026-07-13',
        state: ProgressCellState.notCompleted,
      ),
      SevenDayProgressCell(
        localDate: '2026-07-14',
        state: ProgressCellState.empty,
      ),
    ];
    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        providers: [Provider<int>.value(value: 0)],
        child: Scaffold(
          body: SevenDayProgressGrid(
            progress: const SevenDayProgressModel(
              subjectId: 'action-1',
              startDate: '2026-07-12',
              endDate: '2026-07-18',
              cells: cells,
            ),
            onCellTap: (cell) => tapped = cell,
          ),
        ),
      ),
    );

    expect(find.text('1/7'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    final firstCell = find.byKey(const ValueKey('progress-cell-2026-07-12'));
    expect(tester.getSize(firstCell).width, 44);
    expect(tester.getSize(firstCell).height, greaterThanOrEqualTo(44));

    await tester.tap(firstCell);
    await tester.pump();
    expect(tapped?.localDate, '2026-07-12');
  });

  testWidgets('来源变化时立即显示原位更新并说明旧候选不可采纳', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        providers: [Provider<int>.value(value: 0)],
        child: const Scaffold(
          body: CandidateRefreshBanner(
            generation: CandidateGenerationState(
              kind: CandidateKind.microAction,
              periodStart: '2026-07-12',
              periodEnd: '2026-07-12',
              status: CandidateGenerationStatus.regenerating,
              staleReason: 'signal_source_changed',
            ),
          ),
        ),
      ),
    );

    expect(find.text('正在根据最新信号更新'), findsOneWidget);
    expect(find.textContaining('旧候选会暂时停用'), findsOneWidget);
    expect(find.textContaining('新候选会在原位置替换'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
