import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'release UI direct literals do not bypass four-language localization',
    () {
      final violations = <String>[];
      final directText = RegExp(
        r'''(?<![A-Za-z0-9_])(?:Text|TextSpan)\s*\(\s*(?:text\s*:\s*)?(?:const\s*)?['"]([^'"]*)['"]''',
      );
      final directProperty = RegExp(
        r'''(?:hintText|labelText|helperText|tooltip|semanticsLabel)\s*:\s*['"]([^'"]*)['"]''',
      );
      final readerFacingScript = RegExp(
        r'[A-Za-z\u3400-\u4DBF\u4E00-\u9FFF\u3040-\u30FF]',
      );

      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) =>
              file.path.endsWith('.dart') &&
              !file.path.contains('/features/debug/'))) {
        final source = file.readAsStringSync();
        for (final pattern in [directText, directProperty]) {
          for (final match in pattern.allMatches(source)) {
            final copy = (match.group(1) ?? '')
                .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
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
            if (!readerFacingScript.hasMatch(copy)) continue;
            final line =
                '\n'.allMatches(source.substring(0, match.start)).length + 1;
            violations.add(
              '${file.path}:$line bypasses localization with '
              '"${match.group(1)}"',
            );
          }
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  test(
    'release UI does not bypass localization with direct English badges',
    () {
      final violations = <String>[];
      final directText = RegExp(
        r'''(?:const\s+)?Text\s*\(\s*(['"])(?:PRO|Pro|AI|Weekly|Journey|Today|Life Experiment|Observation)\1''',
        caseSensitive: false,
      );
      final untranslatedTernary = RegExp(
        r'''\?\s*(['"])(?:PRO|Pro|AI|Weekly|Journey|Today|Life Experiment|Observation)\1\s*:''',
        caseSensitive: false,
      );

      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) =>
              file.path.endsWith('.dart') &&
              !file.path.contains('/features/debug/'))) {
        final source = file.readAsStringSync();
        for (final pattern in [directText, untranslatedTernary]) {
          for (final match in pattern.allMatches(source)) {
            final line =
                '\n'.allMatches(source.substring(0, match.start)).length + 1;
            violations.add('${file.path}:$line uses ${match.group(0)}');
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
}
