import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/i18n/weekly_report_text.dart';
import 'package:ai_opportunity_radar/core/preferences/focus_domains.dart';
import 'package:ai_opportunity_radar/features/pages/memory/journey_display_text.dart';

void main() {
  testWidgets(
    'English and Japanese chart legends classify legacy dynamic text into the nine focus domains',
    (tester) async {
      for (final expectation in const [
        (locale: Locale('en'), sleep: 'food and sleep', plan: 'growth plan'),
        (locale: Locale('ja'), sleep: '食事と睡眠', plan: '成長計画'),
      ]) {
        await tester.pumpWidget(
          _LocalizedHarness(
            locale: expectation.locale,
            builder: (context) => Column(
              children: [
                Text(
                  localizeJourneyChartSeriesLabel(
                    context,
                    categoryId: '其他线索',
                    evidence: const ['最近睡眠不足，白天也很疲惫'],
                  ),
                  key: const ValueKey('sleep-series'),
                ),
                Text(
                  localizeJourneyChartSeriesLabel(
                    context,
                    categoryId: '工作',
                    evidence: const ['计划推进目标'],
                  ),
                  key: const ValueKey('plan-series'),
                ),
              ],
            ),
          ),
        );

        expect(find.text(expectation.sleep), findsOneWidget);
        expect(find.text(expectation.plan), findsOneWidget);
        expect(find.textContaining('其他线索'), findsNothing);
        expect(find.textContaining('工作'), findsNothing);
      }
    },
  );

  testWidgets(
    'all chart taxonomy labels are locale-correct and English remains CJK-free',
    (tester) async {
      for (final locale in const [Locale('en'), Locale('ja')]) {
        await tester.pumpWidget(
          _LocalizedHarness(
            locale: locale,
            builder: (context) => Column(
              children: [
                for (final option in FocusDomains.options)
                  Text(
                    localizeJourneyChartSeriesLabel(
                      context,
                      categoryId: option.id,
                    ),
                  ),
              ],
            ),
          ),
        );

        final labels = tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data)
            .whereType<String>()
            .toList(growable: false);
        final expected = FocusDomains.options
            .map(
                (option) => locale.languageCode == 'en' ? option.en : option.ja)
            .toList(growable: false);
        expect(labels, expected);
        if (locale.languageCode == 'en') {
          expect(labels.join(' '), isNot(matches(_cjkOrKana)));
        }
      }
    },
  );

  testWidgets(
    'Weekly and Deep Analysis chart taxonomy copy is localized before display',
    (tester) async {
      for (final expectation in const [
        (
          locale: Locale('en'),
          text: 'growth plan · draining · boundaries and room'
        ),
        (locale: Locale('ja'), text: '成長計画 · やや消耗 · 境界と余白'),
      ]) {
        await tester.pumpWidget(
          _LocalizedHarness(
            locale: expectation.locale,
            builder: (context) => Text(
              WeeklyReportText.localizeCopy(
                context,
                'growth_plan · draining · boundary_buffer',
              ),
            ),
          ),
        );
        expect(find.text(expectation.text), findsOneWidget);
      }
    },
  );

  testWidgets(
    'persisted weekly action-review phrases do not leak Chinese into English or Japanese',
    (tester) async {
      for (final expectation in const [
        (
          locale: Locale('en'),
          text: 'Continue in this direction · Make it a little lighter'
        ),
        (locale: Locale('ja'), text: 'この方向を続ける · 少し軽くする'),
      ]) {
        await tester.pumpWidget(
          _LocalizedHarness(
            locale: expectation.locale,
            builder: (context) => Text(
              WeeklyReportText.localizeCopy(
                context,
                '继续这个方向 · 调轻一点',
              ),
            ),
          ),
        );
        expect(find.text(expectation.text), findsOneWidget);
        if (expectation.locale.languageCode == 'en') {
          expect(expectation.text, isNot(matches(_cjkOrKana)));
        }
      }
    },
  );

  test('active chart surfaces do not render raw dynamic category ids', () {
    final memory =
        File('lib/features/pages/memory/memory_page.dart').readAsStringSync();
    final journeyPro = File('lib/features/pages/memory/journey_pro_page.dart')
        .readAsStringSync();
    final deepWeekly = File('lib/features/pages/weekly/deep_weekly_page.dart')
        .readAsStringSync();

    expect(memory, contains('localizeJourneyChartSeriesLabel('));
    expect(journeyPro, contains('localizeJourneyChartSeriesLabel('));
    expect(deepWeekly, contains('WeeklyReportText.localizeInsight('));
    expect(deepWeekly, contains('_localizedWeeklyReflectCopy('));
    expect(memory, isNot(contains('label: entry.key')));
  });
}

final _cjkOrKana = RegExp(
  r'[\u3400-\u4DBF\u4E00-\u9FFF\u3040-\u30FF]',
);

class _LocalizedHarness extends StatelessWidget {
  final Locale locale;
  final WidgetBuilder builder;

  const _LocalizedHarness({
    required this.locale,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: Builder(builder: builder)),
    );
  }
}
