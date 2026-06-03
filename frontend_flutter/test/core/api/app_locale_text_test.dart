import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/i18n/app_locale_text.dart';

void main() {
  test('app locale rules map unsupported languages to English', () {
    expect(
      AppLocaleText.resolveFromLocale(const Locale('en')),
      AppLanguage.english,
    );
    expect(
      AppLocaleText.resolveFromLocale(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ),
      AppLanguage.simplifiedChinese,
    );
    expect(
      AppLocaleText.resolveFromLocale(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      AppLanguage.traditionalChinese,
    );
    expect(
      AppLocaleText.resolveFromLocale(const Locale('zh', 'TW')),
      AppLanguage.traditionalChinese,
    );
    expect(
      AppLocaleText.resolveFromLocale(const Locale('ja')),
      AppLanguage.japanese,
    );
    expect(
      AppLocaleText.resolveFromLocale(const Locale('fr')),
      AppLanguage.english,
    );
  });
}
