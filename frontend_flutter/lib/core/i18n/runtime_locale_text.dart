import 'dart:ui' as ui;

/// Locale selection for copy produced outside a widget tree.
///
/// Repository fallbacks are persisted and later rendered by several screens,
/// so they must use the same four-language contract as visible widget copy.
class RuntimeLocaleText {
  const RuntimeLocaleText._();

  static String deviceLanguageCode() {
    final locale = ui.PlatformDispatcher.instance.locale;
    if (locale.languageCode.toLowerCase() == 'ja') return 'ja';
    if (locale.languageCode.toLowerCase() != 'zh') return 'en';
    final script = locale.scriptCode?.toLowerCase();
    final country = locale.countryCode?.toUpperCase();
    return script == 'hant' ||
            country == 'TW' ||
            country == 'HK' ||
            country == 'MO'
        ? 'zh-Hant'
        : 'zh-Hans';
  }

  static String normalize(String? language) {
    final value = language?.trim().toLowerCase();
    if (value == 'ja' || value?.startsWith('ja-') == true) return 'ja';
    if (value == 'zh-hant' ||
        value == 'zh_tw' ||
        value == 'zh-tw' ||
        value == 'zh_hk' ||
        value == 'zh-hk') {
      return 'zh-Hant';
    }
    if (value == 'zh-hans' ||
        value == 'zh_cn' ||
        value == 'zh-cn' ||
        value == 'zh') {
      return 'zh-Hans';
    }
    return 'en';
  }

  static String tr({
    String? language,
    required String en,
    required String zhHans,
    required String zhHant,
    required String ja,
  }) {
    switch (normalize(language ?? deviceLanguageCode())) {
      case 'zh-Hans':
        return zhHans;
      case 'zh-Hant':
        return zhHant;
      case 'ja':
        return ja;
      default:
        return en;
    }
  }
}
