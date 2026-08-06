import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/shared/utils/l1_attunement_fallback.dart';
import 'package:ai_opportunity_radar/shared/utils/user_visible_text_sanitizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AI prediction confirmation status is never shown as an L1 reply', () {
    const legacyStatusMessages = [
      '这条内容已从 AI 预判确认并加入时间线。',
      '這條內容已從 AI 預判確認並加入時間線。',
      'AI予測から確認し、タイムラインに追加しました。',
      'Confirmed from an AI prediction and added to your timeline.',
    ];

    for (final message in legacyStatusMessages) {
      expect(
        sanitizeTimelineAcknowledgement(message),
        isNull,
        reason: message,
      );
    }
  });

  test('a real emotion acknowledgement remains visible', () {
    expect(
      sanitizeTimelineAcknowledgement(
        '一下子有这么多事压过来，确实很容易让人喘不过气。',
      ),
      isNotNull,
    );
  });

  test('empty L1 source text uses the requested language fallback', () {
    expect(
      l1AttunedAcknowledgement(content: '', language: 'zh-Hant'),
      contains('這一刻的感受'),
    );
    expect(
      l1AttunedAcknowledgement(content: '', language: 'ja'),
      contains('今この瞬間の気持ち'),
    );
    expect(
      l1AttunedAcknowledgement(content: '', language: 'en'),
      contains('what you are feeling right now'),
    );
  });

  for (final testCase in <({Locale locale, String expected})>[
    (
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
      expected: '本周可留意：“工作”时的“身体紧绷”，频繁切换后仍是“未分类”。Signal 与 Signal Path 保持原样。',
    ),
    (
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
      ),
      expected: '本週可留意：“工作”時的“身體緊繃”，頻繁切換後仍是“未分類”。Signal 與 Signal Path 保持原樣。',
    ),
    (
      locale: const Locale('ja'),
      expected:
          '今週は「仕事」の「身体のこわばり」を確認。頻繁な切り替えの後も“未分類”。Signal と Signal Path はそのまま。',
    ),
    (
      locale: const Locale('en'),
      expected:
          'Notice “work” and “body tension” after frequent context switching; “uncategorized”. Keep Signal and Signal Path.',
    ),
  ]) {
    testWidgets(
      'dynamic machine labels are localized for ${testCase.locale}',
      (tester) async {
        late String actual;
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
                  'ja' =>
                    '今週は「work」の「body_tension」を確認。context_switchingの後も“unknown”。Signal と Signal Path はそのまま。',
                  'en' =>
                    'Notice “work” and “body_tension” after context_switching; “unknown”. Keep Signal and Signal Path.',
                  _ when testCase.locale.scriptCode == 'Hant' =>
                    '本週可留意：“work”時的“body_tension”，context_switching後仍是“unknown”。Signal 與 Signal Path 保持原樣。',
                  _ =>
                    '本周可留意：“work”时的“body_tension”，context_switching后仍是“unknown”。Signal 与 Signal Path 保持原样。',
                };
                actual = localizeUserVisibleDynamicText(context, raw);
                return Text(actual);
              },
            ),
          ),
        );

        expect(actual, testCase.expected);
        expect(find.textContaining('body_tension'), findsNothing);
        expect(find.textContaining('context_switching'), findsNothing);
        expect(find.textContaining('unknown'), findsNothing);
      },
    );
  }

  testWidgets(
    'natural user-authored English remains unchanged while machine ids localize',
    (tester) async {
      late String actual;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
          ),
          supportedLocales: const [
            Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hans',
            ),
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(builder: (context) {
            actual = localizeUserVisibleDynamicText(
              context,
              '最近喜欢 rap，也在 growth_plan 里记录下来。',
            );
            return Text(actual);
          }),
        ),
      );

      expect(actual, '最近喜欢 rap，也在 成长计划 里记录下来。');
    },
  );

  testWidgets(
    'unknown machine keys and health hint copy never leak in simplified Chinese',
    (tester) async {
      late String unknownKeyCopy;
      late String healthHintCopy;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
          ),
          supportedLocales: const [
            Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hans',
            ),
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(builder: (context) {
            unknownKeyCopy = localizeUserVisibleDynamicText(
              context,
              '本周还出现了 novel_backend_enum。',
            );
            healthHintCopy = localizeUserVisibleDynamicText(
              context,
              'Workout load may ask for a little more recovery room.',
            );
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(unknownKeyCopy, '本周还出现了 其他线索。');
      expect(unknownKeyCopy, isNot(contains('novel_backend_enum')));
      expect(healthHintCopy, '近期运动负担较高，可能需要多留一点恢复空间。');
    },
  );

  testWidgets(
    'technical English errors are replaced by localized reader-facing copy',
    (tester) async {
      late String englishError;
      late String chineseError;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
          ),
          supportedLocales: const [
            Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hans',
            ),
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(builder: (context) {
            englishError = localizeUserVisibleErrorText(
              context,
              'SocketException: request failed',
            );
            chineseError = localizeUserVisibleErrorText(
              context,
              '本地数据暂时不可用。',
            );
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(englishError, '暂时无法完成，请稍后重试。');
      expect(chineseError, '本地数据暂时不可用。');
    },
  );

  testWidgets(
    'errors from another language never cross into English or Japanese UI',
    (tester) async {
      late String japaneseUi;
      late String englishUi;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          supportedLocales: const [Locale('ja')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(builder: (context) {
            japaneseUi = localizeUserVisibleErrorText(
              context,
              '本地数据暂时不可用。',
            );
            return const SizedBox.shrink();
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(builder: (context) {
            englishUi = localizeUserVisibleErrorText(
              context,
              '本地数据暂时不可用。',
            );
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(
        japaneseUi,
        '一時的に完了できませんでした。しばらくしてから再試行してください。',
      );
      expect(englishUi, 'Something went wrong. Please try again.');
    },
  );

  testWidgets(
    'quoted aliases and energy enums are localized in simplified Chinese',
    (tester) async {
      late String actual;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
          ),
          supportedLocales: const [
            Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hans',
            ),
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(builder: (context) {
            actual = localizeUserVisibleDynamicText(
              context,
              '“body tension”属于 draining，boundary_buffer 仍是“Signal Card”。',
            );
            return Text(actual);
          }),
        ),
      );

      expect(actual, '“身体紧绷”属于 偏耗力，边界与余地 仍是“信号卡”。');
      expect(actual, isNot(contains('body tension')));
      expect(actual, isNot(contains('draining')));
      expect(actual, isNot(contains('boundary_buffer')));
      expect(actual, isNot(contains('Signal Card')));
    },
  );

  testWidgets(
    'generated machine labels leave no English outside approved names',
    (tester) async {
      final rendered = <String>[];
      for (final locale in const [
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        Locale('ja'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: const [
              Locale('ja'),
              Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
              Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
            ],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(builder: (context) {
              rendered.addAll([
                localizeUserVisibleDynamicText(
                  context,
                  'ai_prediction / signal_card / signal_path',
                ),
                localizeUserVisibleDynamicText(
                  context,
                  'Health recovery hints are unavailable right now. Energy Budget can still use your internal Signal Card observations.',
                ),
                localizeUserVisibleDynamicText(
                  context,
                  'Calendar access is optional. Energy Budget can keep using your internal Signal Card observations.',
                ),
              ]);
              return const SizedBox.shrink();
            }),
          ),
        );
      }

      expect(rendered, hasLength(9));
      for (final copy in rendered) {
        final withoutApprovedNames = copy
            .replaceAll('Signal Path', '')
            .replaceAll(RegExp(r'\bSignal\b'), '');
        expect(
          RegExp(r'[A-Za-z]').hasMatch(withoutApprovedNames),
          isFalse,
          reason: copy,
        );
      }
    },
  );
}
