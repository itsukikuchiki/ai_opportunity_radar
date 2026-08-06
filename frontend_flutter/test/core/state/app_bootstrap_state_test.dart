import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/diagnostics/privacy_safe_logger.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/state/app_bootstrap_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('notification destination is consumed once without creating data',
      () async {
    var reads = 0;
    final state = AppBootstrapState(
      signalReminderTodayDestinationReader: () async {
        reads += 1;
        return true;
      },
    );

    expect(state.signalReminderTodayPending, isFalse);
    expect(await state.refreshSignalReminderTodayDestination(), isTrue);
    expect(state.signalReminderTodayPending, isTrue);
    expect(await state.refreshSignalReminderTodayDestination(), isTrue);
    expect(reads, 1);

    state.dispose();
  });

  test('production launch clears QA-owned routing preferences before routing',
      () async {
    SharedPreferences.setMockInitialValues({
      'qa_showcase_seed_signature_v2': '2026-07-31|en|localized_v5',
      'profile_display_name': 'Signal Path QA',
      'onboarding_completed': true,
      'onboardingCompleted': true,
      'local_app_started_date': '2026-07-10T00:00:00.000',
    });
    final state = AppBootstrapState();

    await state.prepareLaunch();

    final prefs = await SharedPreferences.getInstance();
    expect(state.onboardingCompleted, isFalse);
    expect(prefs.getString('qa_showcase_seed_signature_v2'), isNull);
    expect(prefs.getString('profile_display_name'), isNull);
    expect(prefs.getBool('onboarding_completed'), isNull);
    expect(prefs.getBool('onboardingCompleted'), isNull);
    expect(prefs.getString('local_app_started_date'), isNull);
    state.dispose();
  });

  test('production launch preserves ordinary user routing preferences',
      () async {
    SharedPreferences.setMockInitialValues({
      'profile_display_name': 'A real profile name',
      'onboarding_completed': true,
      'onboardingCompleted': true,
      'local_app_started_date': '2026-06-01T00:00:00.000',
    });
    final state = AppBootstrapState();

    await state.prepareLaunch();

    final prefs = await SharedPreferences.getInstance();
    expect(state.onboardingCompleted, isTrue);
    expect(prefs.getString('profile_display_name'), 'A real profile name');
    expect(prefs.getBool('onboarding_completed'), isTrue);
    expect(prefs.getBool('onboardingCompleted'), isTrue);
    expect(
      prefs.getString('local_app_started_date'),
      '2026-06-01T00:00:00.000',
    );
    state.dispose();
  });

  test('data deletion rebuilds dependencies with a new anonymous identity',
      () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'onboardingCompleted': true,
      'legacy_schedule_notifications_cleared_v1': true,
    });
    final tempDir =
        await Directory.systemTemp.createTemp('app_bootstrap_state_test_');
    final databases = <LocalDatabase>[];
    final dependencies = <AppDependencies>[];
    var factoryCalls = 0;

    Future<AppDependencies> createDependencies() async {
      factoryCalls += 1;
      final database = LocalDatabase(
        dbPathOverride: p.join(tempDir.path, 'local-$factoryCalls.db'),
        databaseFactoryOverride: databaseFactoryFfi,
      );
      databases.add(database);
      final value = await AppDependencies.create(
        localDatabaseOverride: database,
        trackNewUserRegistration: false,
      );
      dependencies.add(value);
      return value;
    }

    final state = AppBootstrapState(
      dependenciesFactory: createDependencies,
    );
    await state.prepareLaunch();
    await state.init();
    final before = state.dependencies;
    final beforeUserId = before.localUserId;
    final beforeDeviceId = before.deviceId;
    expect(state.onboardingCompleted, isTrue);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_user_id');
    await prefs.remove('device_id');
    final initializedTransitions = <bool>[];
    state.addListener(() => initializedTransitions.add(state.initialized));

    await state.resetAfterDataDeletion();

    final after = state.dependencies;
    expect(factoryCalls, 2);
    expect(identical(before, after), isFalse);
    expect(after.localUserId, isNot(beforeUserId));
    expect(after.deviceId, isNot(beforeDeviceId));
    expect(prefs.getString('local_user_id'), after.localUserId);
    expect(prefs.getString('device_id'), after.deviceId);
    expect(state.onboardingCompleted, isFalse);
    expect(prefs.getBool('onboarding_completed'), isFalse);
    expect(prefs.getBool('onboardingCompleted'), isFalse);
    expect(initializedTransitions, [false, true]);
    expect(state.hasError, isFalse);

    state.dispose();
    for (final value in dependencies) {
      await value.localCandidatePlanningRepository.dispose();
    }
    for (final database in databases) {
      await database.close();
    }
    await tempDir.delete(recursive: true);
  });

  test('initialization failure exposes only a safe reference and can retry',
      () async {
    SharedPreferences.setMockInitialValues({
      'legacy_schedule_notifications_cleared_v1': true,
    });
    var attempts = 0;
    final records = <PrivacySafeLogRecord>[];
    final logger = PrivacySafeLogger(
      sink: records.add,
      idFactory: () => 'init-event-${attempts + 1}',
    );
    final state = AppBootstrapState(
      logger: logger,
      dependenciesFactory: () async {
        attempts += 1;
        throw StateError('raw database path /private/user/diary.db');
      },
    );

    await state.prepareLaunch();
    await state.init();

    expect(state.initialized, isTrue);
    expect(state.hasError, isTrue);
    expect(state.initErrorEventId, 'init-event-2');
    expect(records, hasLength(1));
    expect(records.single.toSafeLine(), isNot(contains('/private/user')));

    await state.retryInitialization();

    expect(attempts, 2);
    expect(state.initialized, isTrue);
    expect(state.hasError, isTrue);
    expect(records, hasLength(2));
    state.dispose();
  });
}
