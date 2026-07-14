import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('candidate planning shares the app Energy Budget and feedback sources',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_user_id': 'wiring-user',
      'device_id': 'wiring-device',
    });
    final tempDir =
        await Directory.systemTemp.createTemp('app_dependencies_test_');
    final localDatabase = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'local.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    final dependencies = await AppDependencies.create(
      localDatabaseOverride: localDatabase,
      trackNewUserRegistration: false,
    );

    expect(
      identical(
        dependencies.energyBudgetRepository,
        dependencies.localCandidatePlanningRepository.energyBudgetRepository,
      ),
      isTrue,
    );
    expect(
      identical(
        dependencies.energyBudgetRepository.feedbackEventRepository,
        dependencies.localCandidatePlanningRepository.feedbackEventRepository,
      ),
      isTrue,
    );
    expect(
      identical(
        dependencies.localCaptureRepository,
        dependencies.energyBudgetRepository.localCaptureRepository,
      ),
      isTrue,
    );

    await dependencies.localCandidatePlanningRepository.dispose();
    await localDatabase.close();
    await tempDir.delete(recursive: true);
  });
}
