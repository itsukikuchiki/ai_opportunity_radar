import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iOS native release configuration', () {
    test('real StoreKit scheme is isolated from the local StoreKit scheme', () {
      final releaseScheme = _read(
        'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
      );
      final localScheme = _read(
        'ios/Runner.xcodeproj/xcshareddata/xcschemes/'
        'Runner-LocalStoreKit.xcscheme',
      );

      expect(
        releaseScheme,
        isNot(contains('StoreKitConfigurationFileReference')),
        reason: 'Runner must use the real App Store environment.',
      );
      expect(releaseScheme, isNot(contains('.storekit')));
      expect(localScheme, contains('StoreKitConfigurationFileReference'));
      expect(localScheme, contains('identifier = "../SignalPath.storekit"'));
    });

    test('local StoreKit products use final Pro copy in all four locales', () {
      final storeKit = _readJson('ios/SignalPath.storekit');
      final groups = (storeKit['subscriptionGroups'] as List<dynamic>)
          .map((value) => (value as Map).cast<String, dynamic>());
      final products = groups
          .expand(
            (group) => (group['subscriptions'] as List<dynamic>)
                .map((value) => (value as Map).cast<String, dynamic>()),
          )
          .toList();

      expect(
        products.map((product) => product['productID']),
        unorderedEquals(const {
          'jp.sunrise.signalpath.pro.monthly',
          'jp.sunrise.signalpath.pro.yearly',
        }),
      );

      const requiredCopy = <String, List<String>>{
        'en_US': [
          'weekly deep analysis',
          'action-preference insights',
          'complete Journey timeline since first use',
          'structured self-review',
          'AI',
        ],
        'zh_CN': [
          '本周深度分析',
          '行动偏好',
          '首次使用至今的旅程完整时间轴',
          '结构化自我复盘',
          '智能功能',
        ],
        'zh_TW': [
          '本週深度分析',
          '行動偏好',
          '首次使用至今的旅程完整時間軸',
          '結構化自我複盤',
          '智慧功能',
        ],
        'ja_JP': [
          '今週の深い分析',
          '行動傾向',
          '初回利用から現在までの旅程の全期間タイムライン',
          '構造化された自己振り返り',
          '知能機能',
        ],
      };
      const displayNamePrefixes = <String, String>{
        'en_US': 'Signal Path Pro',
        'zh_CN': 'Signal Path 专业版',
        'zh_TW': 'Signal Path 專業版',
        'ja_JP': 'Signal Path プロ版',
      };

      for (final product in products) {
        final localizations = (product['localizations'] as List<dynamic>)
            .map((value) => (value as Map).cast<String, dynamic>());
        final byLocale = <String, Map<String, dynamic>>{
          for (final localization in localizations)
            localization['locale']! as String: localization,
        };
        expect(
          byLocale.keys,
          unorderedEquals(requiredCopy.keys),
          reason: '${product['productID']} must ship all supported locales.',
        );

        for (final entry in requiredCopy.entries) {
          final localization = byLocale[entry.key]!;
          final description = localization['description']! as String;
          expect(
            localization['displayName'],
            startsWith(displayNamePrefixes[entry.key]!),
          );
          for (final phrase in entry.value) {
            expect(
              description,
              contains(phrase),
              reason:
                  '${product['productID']} ${entry.key} is missing "$phrase".',
            );
          }
        }
      }
    });

    test('permission copy is localized and embedded as an Xcode resource', () {
      const localePaths = <String, String>{
        'en': 'ios/Runner/en.lproj/InfoPlist.strings',
        'zh-Hans': 'ios/Runner/zh-Hans.lproj/InfoPlist.strings',
        'zh-Hant': 'ios/Runner/zh-Hant.lproj/InfoPlist.strings',
        'ja': 'ios/Runner/ja.lproj/InfoPlist.strings',
      };
      const requiredKeys = <String>{
        'NSCalendarsFullAccessUsageDescription',
        'NSCalendarsUsageDescription',
        'NSHealthShareUsageDescription',
        'NSHealthUpdateUsageDescription',
        'NSMicrophoneUsageDescription',
        'NSPhotoLibraryUsageDescription',
        'NSSpeechRecognitionUsageDescription',
      };
      const onDeviceMarkers = <String, String>{
        'en': 'on-device',
        'zh-Hans': '设备端',
        'zh-Hant': '裝置端',
        'ja': 'デバイス上',
      };
      const readOnlyMarkers = <String, String>{
        'en': 'read-only',
        'zh-Hans': '只读',
        'zh-Hant': '唯讀',
        'ja': '読み取り専用',
      };

      for (final entry in localePaths.entries) {
        final strings = _parseStrings(_read(entry.value));
        expect(
          strings.keys,
          containsAll(requiredKeys),
          reason: '${entry.key} must localize every permission prompt.',
        );
        for (final key in requiredKeys) {
          expect(strings[key], isNotEmpty,
              reason: '${entry.key} $key is empty.');
        }
        expect(
          strings['NSSpeechRecognitionUsageDescription'],
          contains(onDeviceMarkers[entry.key]),
        );
        expect(
          strings['NSHealthUpdateUsageDescription'],
          contains(readOnlyMarkers[entry.key]),
        );
      }

      final project = _read('ios/Runner.xcodeproj/project.pbxproj');
      expect(project, contains('InfoPlist.strings in Resources'));
      expect(project, contains('isa = PBXVariantGroup;'));
      for (final entry in localePaths.entries) {
        expect(project, contains(entry.value.replaceFirst('ios/Runner/', '')));
      }
      final knownRegions = RegExp(
        r'knownRegions = \(([\s\S]*?)\);',
      ).firstMatch(project)!.group(1)!;
      for (final locale in localePaths.keys) {
        expect(knownRegions, contains(locale));
      }
    });

    test('speech recognition is hard-gated to on-device processing', () {
      final appDelegate = _read('ios/Runner/AppDelegate.swift');
      final supportCheck = appDelegate.indexOf('supportsOnDeviceRecognition');
      final onDeviceRequirement = appDelegate.indexOf(
        'request.requiresOnDeviceRecognition = true',
      );
      final recognitionStart = appDelegate.indexOf(
        'recognizer.recognitionTask(with: request)',
      );

      expect(supportCheck, greaterThanOrEqualTo(0));
      expect(onDeviceRequirement, greaterThan(supportCheck));
      expect(recognitionStart, greaterThan(onDeviceRequirement));
      expect(
        appDelegate,
        isNot(contains('request.requiresOnDeviceRecognition = false')),
      );
    });

    test(
        'speech recognition follows device dictation language instead of app display locale',
        () {
      final appDelegate = _read('ios/Runner/AppDelegate.swift');
      final speechBridgeStart = appDelegate.indexOf(
        'private static func startRecognitionSession() throws',
      );
      final speechBridgeEnd = appDelegate.indexOf(
        'private static func finishAudioInput()',
      );
      final speechBridge = appDelegate.substring(
        speechBridgeStart,
        speechBridgeEnd,
      );

      expect(speechBridge, contains('SFSpeechRecognizer()'));
      expect(speechBridge, isNot(contains('SFSpeechRecognizer(locale:')));
      expect(speechBridge, isNot(contains('englishFallbackLocale')));
      expect(appDelegate, isNot(contains('localeIdentifier')));
    });

    test('Calendar retains read support without requesting native permission',
        () {
      final appDelegate = _read('ios/Runner/AppDelegate.swift');

      expect(appDelegate, isNot(contains('requestFullAccessToEvents')));
      expect(appDelegate, isNot(contains('requestWriteOnlyAccessToEvents')));
      expect(
        RegExp(r'requestAccess\s*\(\s*to:\s*\.event').hasMatch(appDelegate),
        isFalse,
      );
      expect(appDelegate, contains('guard status == "authorized" else'));
    });

    test('HealthKit authorization remains read-only with no write path', () {
      final appDelegate = _read('ios/Runner/AppDelegate.swift');
      final healthRequest = _between(
        appDelegate,
        'private static func requestHealthRecoveryHints',
        'private static func healthReadTypes',
      );
      final healthQueries = _between(
        appDelegate,
        'private static func averageSteps',
        '\n}\n\nprivate final class NativeStoreKitBridge',
      );

      expect(
        RegExp(
          r'healthStore\.requestAuthorization\s*\('
          r'\s*toShare:\s*nil,\s*read:\s*types\s*\)',
        ).hasMatch(appDelegate),
        isTrue,
      );
      expect(
        healthRequest,
        isNot(contains('"permission_status": "denied"')),
        reason: 'HealthKit does not reveal whether read access was denied.',
      );
      expect(healthRequest, contains('requestCompleted, error'));
      expect(healthRequest, contains('"permission_status": "unavailable"'));

      expect(
        RegExp(
          r'private static func '
          r'(averageSteps|totalWorkoutMinutes|averageSleepHours)'
          r'\(\) async -> Double\?',
        ).allMatches(healthQueries).map((match) => match.group(1)),
        unorderedEquals(const {
          'averageSteps',
          'totalWorkoutMinutes',
          'averageSleepHours',
        }),
        reason: 'Every HealthKit aggregate query must preserve no-data as nil.',
      );
      expect(
        RegExp(r'continuation\.resume\(returning: nil\)')
            .allMatches(healthQueries)
            .length,
        greaterThanOrEqualTo(3),
      );
      expect(healthQueries, isNot(contains('return 0')));
      expect(healthRequest, isNot(contains('?? 0')));
      expect(healthRequest, contains('let sleepScore = sleepHours.map'));
      expect(healthRequest, contains('let movementScore = steps.map'));
      expect(
        healthRequest,
        contains('let workoutLoadScore = workoutMinutes.map'),
      );
      expect(healthRequest, contains('if recoveryComponents.isEmpty'));
      expect(healthRequest, contains('payload["no_data"] = true'));
      expect(
        healthRequest,
        isNot(contains('"sleep_recovery_score": sleepScore')),
        reason: 'Optional scores must not be inserted into the base payload.',
      );
      expect(appDelegate, isNot(contains('healthStore.save(')));
      expect(appDelegate, isNot(contains('healthStore.delete(')));
      expect(appDelegate, isNot(contains('HKQuantitySample(')));
      expect(appDelegate, isNot(contains('HKCategorySample(')));

      final infoPlist = _read('ios/Runner/Info.plist');
      expect(infoPlist, contains('NSHealthUpdateUsageDescription'));
      expect(infoPlist, contains('does not add or modify Health data'));
      expect(infoPlist, contains('read-only'));
    });

    test('unused Sign in with Apple dependency and registration are absent',
        () {
      const inspectedFiles = <String>[
        'pubspec.yaml',
        'pubspec.lock',
        'ios/Podfile.lock',
        'ios/Runner/GeneratedPluginRegistrant.m',
        'macos/Flutter/GeneratedPluginRegistrant.swift',
        'ios/Runner/Runner.entitlements',
      ];

      for (final path in inspectedFiles) {
        final source = _read(path).toLowerCase();
        expect(
          source,
          isNot(anyOf(
            contains('sign_in_with_apple'),
            contains('signinwithapple'),
            contains('com.apple.developer.applesignin'),
          )),
          reason: '$path still declares or registers Sign in with Apple.',
        );
      }
    });
  });
}

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing required file: $path');
  return file.readAsStringSync();
}

Map<String, dynamic> _readJson(String path) {
  return (jsonDecode(_read(path)) as Map).cast<String, dynamic>();
}

Map<String, String> _parseStrings(String source) {
  return <String, String>{
    for (final match in RegExp(
      r'^"([^"]+)"\s*=\s*"(.*)";$',
      multiLine: true,
    ).allMatches(source))
      match.group(1)!: match.group(2)!,
  };
}

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'Missing marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, greaterThan(startIndex), reason: 'Missing marker: $end');
  return source.substring(startIndex, endIndex);
}
