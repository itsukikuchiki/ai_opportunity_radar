import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Spot try positioning does not regress to legacy quick-try copy', () {
    final legacyCopy = RegExp(
      r'Quick tr(?:y|ies)|quick tr(?:y|ies)|lightweight tr(?:y|ies)|轻量尝试|輕量嘗試|軽く試す',
    );
    final violations = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final match in legacyCopy.allMatches(source)) {
        final line =
            '\n'.allMatches(source.substring(0, match.start)).length + 1;
        violations.add(
          '${file.path}:$line uses legacy copy "${match.group(0)}"',
        );
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test(
    'non-English localized copy keeps only approved product names in English',
    () {
      final violations = <String>[];
      final localizedLiteral = RegExp(
        r'''(zhHans|zhHant|ja)\s*:\s*['"]([^'"]*)['"]''',
      );
      final unexpectedEnglish = RegExp(r'[A-Za-z][A-Za-z0-9]*');

      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        final lines = source.split('\n');
        for (var index = 0; index < lines.length; index++) {
          for (final match in localizedLiteral.allMatches(lines[index])) {
            final locale = match.group(1) ?? 'unknown';
            final copy = match.group(2) ?? '';
            final readerFacingCopy = copy
                .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
                // A same-line nested quote can truncate the lightweight
                // literal matcher inside an interpolation. Treat the rest as
                // expression source, never as reader-facing copy.
                .replaceAll(RegExp(r'\$\{.*'), '')
                .replaceAll(
                  RegExp(
                    r'\$[A-Za-z_][A-Za-z0-9_]*'
                    r'(?:\.[A-Za-z_][A-Za-z0-9_]*)*',
                  ),
                  '',
                )
                .replaceAll(RegExp(r'\\[A-Za-z]'), '')
                .replaceAll('Signal Path', '')
                .replaceAll(RegExp(r'\bSignal\b'), '');
            final leaked = unexpectedEnglish.firstMatch(readerFacingCopy);
            if (leaked == null) continue;
            violations.add(
              '${file.path}:${index + 1} contains "${leaked.group(0)}" '
              'in $locale copy',
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.join('\n'),
      );
    },
  );

  test('English localized copy does not contain Chinese or Japanese scripts',
      () {
    final violations = <String>[];
    final localizedLiteral = RegExp(
      r'''en\s*:\s*['"]([^'"]*)['"]''',
    );
    final unexpectedCjk = RegExp(
      r'[\u3400-\u4DBF\u4E00-\u9FFF\u3040-\u30FF]',
    );

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      final lines = source.split('\n');
      for (var index = 0; index < lines.length; index++) {
        for (final match in localizedLiteral.allMatches(lines[index])) {
          final copy = (match.group(1) ?? '')
              .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
              .replaceAll(RegExp(r'\$\{.*'), '')
              .replaceAll(
                RegExp(
                  r'\$[A-Za-z_][A-Za-z0-9_]*'
                  r'(?:\.[A-Za-z_][A-Za-z0-9_]*)*',
                ),
                '',
              );
          final leaked = unexpectedCjk.firstMatch(copy);
          if (leaked == null) continue;
          violations.add(
            '${file.path}:${index + 1} contains "${leaked.group(0)}" '
            'in English copy',
          );
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('non-English iOS permission copy only keeps approved English names', () {
    final violations = <String>[];
    final valueLiteral = RegExp(r'=\s*"((?:\\.|[^"])*)";');
    final unexpectedEnglish = RegExp(r'[A-Za-z][A-Za-z0-9]*');

    for (final path in const [
      'ios/Runner/zh-Hans.lproj/InfoPlist.strings',
      'ios/Runner/zh-Hant.lproj/InfoPlist.strings',
      'ios/Runner/ja.lproj/InfoPlist.strings',
    ]) {
      final source = File(path).readAsStringSync();
      for (final match in valueLiteral.allMatches(source)) {
        final copy = (match.group(1) ?? '')
            .replaceAll('Signal Path', '')
            .replaceAll(RegExp(r'\bSignal\b'), '');
        final leaked = unexpectedEnglish.firstMatch(copy);
        if (leaked == null) continue;
        final line =
            '\n'.allMatches(source.substring(0, match.start)).length + 1;
        violations.add('$path:$line contains "${leaked.group(0)}"');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('Android launcher uses the localized Signal Path app name', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final strings =
        File('android/app/src/main/res/values/strings.xml').readAsStringSync();

    expect(manifest, contains('android:label="@string/app_name"'));
    expect(manifest, isNot(contains('android:label="ai_opportunity_radar"')));
    expect(
      strings,
      contains('<string name="app_name">Signal Path</string>'),
    );
  });

  test('StoreKit product copy does not mix UI languages', () {
    final config = jsonDecode(
      File('ios/SignalPath.storekit').readAsStringSync(),
    ) as Map<String, dynamic>;
    final unexpectedEnglish = RegExp(r'[A-Za-z][A-Za-z0-9]*');
    final unexpectedCjk = RegExp(
      r'[\u3400-\u4DBF\u4E00-\u9FFF\u3040-\u30FF]',
    );
    final violations = <String>[];
    final groups = config['subscriptionGroups'] as List<dynamic>? ?? const [];

    for (final rawGroup in groups) {
      final group = rawGroup as Map<String, dynamic>;
      final subscriptions =
          group['subscriptions'] as List<dynamic>? ?? const [];
      for (final rawSubscription in subscriptions) {
        final subscription = rawSubscription as Map<String, dynamic>;
        final productId = subscription['productID'] as String? ?? 'unknown';
        final localizations =
            subscription['localizations'] as List<dynamic>? ?? const [];
        for (final rawLocalization in localizations) {
          final localization = rawLocalization as Map<String, dynamic>;
          final locale = localization['locale'] as String? ?? 'unknown';
          for (final field in const ['displayName', 'description']) {
            final original = localization[field] as String? ?? '';
            if (locale == 'en_US') {
              final leaked = unexpectedCjk.firstMatch(original);
              if (leaked != null) {
                violations.add(
                  '$productId $locale $field contains "${leaked.group(0)}"',
                );
              }
              continue;
            }

            final readerFacingCopy = original
                .replaceAll('Signal Path', '')
                .replaceAll(RegExp(r'\bSignal\b'), '');
            final leaked = unexpectedEnglish.firstMatch(readerFacingCopy);
            if (leaked != null) {
              violations.add(
                '$productId $locale $field contains "${leaked.group(0)}"',
              );
            }
          }
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
