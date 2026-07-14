import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/state/app_data_refresh_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('saving a SignalCard dirties every page projection through the bus',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('app_refresh_integration_test_');
    final database = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'local.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await database.init();
    final captures = LocalCaptureRepository(database);
    final loads = <String, int>{};
    final coordinator = AppDataRefreshCoordinator(
      routeLoaders: {
        for (final route in const [
          '/today',
          '/weekly',
          '/experiment',
          '/memory',
          '/me',
        ])
          route: () async => loads[route] = (loads[route] ?? 0) + 1,
      },
    );

    await captures.insertConfirmedSignalCard(
      signalCardId: 'refresh-signal',
      content: '这条保存后所有长期页面都需要重新读取。',
      sourceType: 'text',
      userConfirmation: 'confirmed',
    );

    for (final route in const [
      '/today',
      '/weekly',
      '/experiment',
      '/memory',
      '/me',
    ]) {
      expect(coordinator.isDirty(route), isTrue, reason: route);
      await coordinator.refreshRoute(route);
      expect(loads[route], 1, reason: route);
      expect(coordinator.isDirty(route), isFalse, reason: route);
    }

    coordinator.dispose();
    await database.close();
    await tempDir.delete(recursive: true);
  });
}
