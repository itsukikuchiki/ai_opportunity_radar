import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/i18n/energy_budget_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final testCase in <({Locale locale, String expected})>[
    (
      locale: const Locale('en'),
      expected: 'Costly “starting friction”; recovery “a small start”.',
    ),
    (
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
      expected: '耗力点“启动阻力”；恢复线索“小步启动”。',
    ),
    (
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
      ),
      expected: '耗力點“啟動阻力”；恢復線索“小步啟動”。',
    ),
    (
      locale: const Locale('ja'),
      expected: '消耗点「開始時の負担」・回復「小さく始める」。',
    ),
  ]) {
    testWidgets(
      'Energy Budget taxonomy is presentation-localized for ${testCase.locale}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: testCase.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('ja'),
              Locale.fromSubtags(
                languageCode: 'zh',
                scriptCode: 'Hans',
              ),
              Locale.fromSubtags(
                languageCode: 'zh',
                scriptCode: 'Hant',
              ),
            ],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) {
                final raw = switch (testCase.locale.languageCode) {
                  'en' => 'Costly “starting”; recovery “small_start”.',
                  'ja' => '消耗点「starting」・回復「small_start」。',
                  _ when testCase.locale.scriptCode == 'Hant' =>
                    '耗力點“starting”；恢復線索“small_start”。',
                  _ => '耗力点“starting”；恢复线索“small_start”。',
                };
                return Text(EnergyBudgetText.localizeCopy(context, raw));
              },
            ),
          ),
        );

        expect(find.text(testCase.expected), findsOneWidget);
        expect(find.textContaining('small_start'), findsNothing);
        expect(find.textContaining('“starting”'), findsNothing);
        expect(find.textContaining('「starting」'), findsNothing);
      },
    );
  }

  for (final testCase in <({Locale locale, String expected})>[
    (locale: const Locale('en'), expected: 'growth plan'),
    (
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
      expected: '成长计划',
    ),
    (
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
      ),
      expected: '成長計劃',
    ),
    (locale: const Locale('ja'), expected: '成長計画'),
  ]) {
    testWidgets(
      'Energy Budget canonical focus domain is localized for ${testCase.locale}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: testCase.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('ja'),
              Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
              Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
            ],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) => Column(
                children: [
                  Text(
                    EnergyBudgetText.localizeCopy(context, 'growth_plan'),
                  ),
                  Text(
                    EnergyBudgetText.localizeCopy(
                      context,
                      'Scene “growth_plan”.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text(testCase.expected), findsOneWidget);
        expect(find.text('Scene “${testCase.expected}”.'), findsOneWidget);
        expect(find.textContaining('growth_plan'), findsNothing);
      },
    );
  }

  testWidgets('unquoted natural copy is not rewritten', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Text(
            EnergyBudgetText.localizeCopy(
              context,
              'This work is starting to feel easier.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('This work is starting to feel easier.'), findsOneWidget);
  });
}
