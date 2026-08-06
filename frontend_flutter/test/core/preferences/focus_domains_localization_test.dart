import 'package:ai_opportunity_radar/core/preferences/focus_domains.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<String> descriptionFor(
    WidgetTester tester,
    Locale locale,
  ) async {
    var description = '';
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [
          Locale('en'),
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
          Locale('ja'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            description =
                FocusDomains.optionFor('growth_plan')!.description(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return description;
  }

  testWidgets('focus-domain descriptions follow all four app locales',
      (tester) async {
    expect(
      await descriptionFor(tester, const Locale('en')),
      'Goals, sticking points, practice, and next steps',
    );
    expect(
      await descriptionFor(
        tester,
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ),
      '目标、卡点、练习与下一步',
    );
    expect(
      await descriptionFor(
        tester,
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      '目標、卡點、練習與下一步',
    );
    expect(
      await descriptionFor(tester, const Locale('ja')),
      '目標、つまずき、練習と次の一歩',
    );
  });
}
