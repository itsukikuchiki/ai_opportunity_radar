import 'package:flutter/material.dart';

enum AppLanguage {
  english,
  simplifiedChinese,
  traditionalChinese,
  japanese,
}

class AppLocaleText {
  const AppLocaleText._();

  static AppLanguage resolve(BuildContext context) {
    return resolveFromLocale(Localizations.localeOf(context));
  }

  static AppLanguage resolveFromLocale(Locale locale) {
    final languageCode = locale.languageCode.toLowerCase();
    final scriptCode = locale.scriptCode?.toLowerCase();
    final countryCode = locale.countryCode?.toUpperCase();

    if (languageCode == 'ja') {
      return AppLanguage.japanese;
    }

    if (languageCode == 'zh') {
      final isTraditional =
          scriptCode == 'hant' ||
          countryCode == 'TW' ||
          countryCode == 'HK' ||
          countryCode == 'MO';

      return isTraditional
          ? AppLanguage.traditionalChinese
          : AppLanguage.simplifiedChinese;
    }

    return AppLanguage.english;
  }

  static String tr(
    BuildContext context, {
    required String en,
    required String zhHans,
    required String zhHant,
    required String ja,
  }) {
    switch (resolve(context)) {
      case AppLanguage.simplifiedChinese:
        return zhHans;
      case AppLanguage.traditionalChinese:
        return zhHant;
      case AppLanguage.japanese:
        return ja;
      case AppLanguage.english:
        return en;
    }
  }
}
