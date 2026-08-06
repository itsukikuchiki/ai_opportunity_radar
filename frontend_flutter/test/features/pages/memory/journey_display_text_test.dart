import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/features/pages/memory/journey_display_text.dart';

void main() {
  testWidgets('小实验完成状态和旧标题在旅程中本地化', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        supportedLocales: const [
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Column(
            children: [
              Text(
                localizeJourneyEvidenceText(
                  context,
                  sourceType: 'micro_action_feedback',
                  text: 'completed · unclear',
                ),
              ),
              Text(
                localizeJourneyCategoryLabel(
                  context,
                  'Micro Action Feedback',
                ),
              ),
              Text(
                journeySourceTypeLabel(
                  context,
                  'life_experiment_feedback',
                ),
              ),
              Text(
                localizeJourneyCategoryLabel(context, 'SignalCard'),
              ),
              Text(
                localizeJourneyEvidenceText(
                  context,
                  sourceType: 'micro_action_feedback',
                  text: 'not_suitable_today',
                ),
              ),
              Text(
                localizeJourneyEvidenceText(
                  context,
                  sourceType: 'signal_card',
                  text: 'no conclusion yet',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('已完成 · 尚不明确'), findsOneWidget);
    expect(find.text('未完成'), findsOneWidget);
    expect(find.text('no conclusion yet'), findsOneWidget);
    expect(find.text('生活小实验 · 小实验反馈'), findsOneWidget);
    expect(find.text('生活小实验 · 目标反馈'), findsOneWidget);
    expect(find.text('信号卡'), findsOneWidget);
  });
}
