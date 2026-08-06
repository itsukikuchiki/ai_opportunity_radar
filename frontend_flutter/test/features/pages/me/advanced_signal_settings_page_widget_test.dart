import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/core/local/external_energy_hint_store.dart';
import 'package:ai_opportunity_radar/core/state/app_data_refresh_coordinator.dart';
import 'package:ai_opportunity_radar/features/pages/me/advanced_signal_settings_page.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('signalpath/external_energy');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
      'Connected insights shows all three impacts and keeps raw Health data hidden',
      (tester) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'healthPermissionStatus':
          return 'not_requested';
        case 'requestHealthRecoveryHints':
          return {
            'permission_status': 'authorized',
            'sleep_recovery_score': 0.38,
            'movement_recovery_score': 0.52,
            'workout_load_score': 0.74,
            'recovery_score': 0.40,
            'workout_title': 'Private medical recovery session',
            'heart_rate_samples': [71, 74, 80],
          };
      }
      return null;
    });

    final store = await _buildStore();

    await tester.pumpWidget(
      MaterialApp(home: AdvancedSignalSettingsPage(hintStore: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connected insights'), findsOneWidget);
    expect(find.text('How Health data participates'), findsOneWidget);
    expect(find.text('Today overview'), findsOneWidget);
    expect(find.text('Weekly review'), findsOneWidget);
    expect(find.text('Life experiments'), findsOneWidget);
    expect(find.text('Calendar schedule density'), findsNothing);
    expect(
        find.textContaining('Private medical recovery session'), findsNothing);
    expect(calls, ['healthPermissionStatus']);

    final refresh = AppDataMutationBus.stream.firstWhere(
      (mutation) => mutation.reason == 'health_energy_hints_changed',
    );
    final enable = find.byKey(const ValueKey('advanced-signals-health-enable'));
    await tester.scrollUntilVisible(enable, 320);
    await tester.pump();
    expect(find.text('Health data'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.textContaining('never writes Health data'), findsOneWidget);
    await tester.tap(enable);
    await tester.pumpAndSettle();
    expect((await refresh.timeout(const Duration(seconds: 2))).kind,
        AppDataMutationKind.externalEnergyHints);

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Update connected data'), findsOneWidget);
    expect(find.text('Clear connected data'), findsOneWidget);
    expect(find.text('Current connected summary'), findsOneWidget);
    expect(store.loadHealthSummary().lowRecoveryHint, isNotNull);
    expect(
        find.textContaining('Private medical recovery session'), findsNothing);
    expect(calls, isNot(contains('calendarPermissionStatus')));
    expect(calls, isNot(contains('requestCalendarScheduleHints')));
  });

  testWidgets(
      'reopen loads saved hints; clear removes them and publishes refresh',
      (tester) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'healthPermissionStatus') return 'not_requested';
      return null;
    });
    final store = await _buildStore();
    await store.saveHealthHints(const {
      'low_recovery_hint': 'Persisted abstract recovery hint.',
      'raw_sleep_samples': 'must never be shown',
    });

    await tester.pumpWidget(
      MaterialApp(home: AdvancedSignalSettingsPage(hintStore: store)),
    );
    await tester.pumpAndSettle();

    final clear = find.byKey(const ValueKey('advanced-signals-health-clear'));
    await tester.scrollUntilVisible(clear, 320);
    await tester.pump();
    expect(find.textContaining('Persisted abstract recovery hint'),
        findsOneWidget);
    expect(find.textContaining('must never be shown'), findsNothing);
    expect(find.text('Connected'), findsOneWidget);

    final refresh = AppDataMutationBus.stream.firstWhere(
      (mutation) => mutation.reason == 'health_energy_hints_cleared',
    );
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect((await refresh.timeout(const Duration(seconds: 2))).kind,
        AppDataMutationKind.externalEnergyHints);

    expect(store.loadHealthSummary().hasAnyHint, isFalse);
    expect(find.textContaining('Connected Health context was removed'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('advanced-signals-health-clear')),
        findsNothing);
    expect(calls, ['healthPermissionStatus']);
  });

  testWidgets('load error recovers and denied authorization never stays busy',
      (tester) async {
    var failStatus = true;
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'healthPermissionStatus') {
        if (failStatus) {
          throw PlatformException(code: 'health_status_failed');
        }
        return 'not_requested';
      }
      if (call.method == 'requestHealthRecoveryHints') {
        return {
          'permission_status': 'denied',
          'read_failed': true,
        };
      }
      return null;
    });
    final store = await _buildStore();

    await tester.pumpWidget(
      MaterialApp(home: AdvancedSignalSettingsPage(hintStore: store)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    final retry = find.byKey(const ValueKey('advanced-signals-health-retry'));
    await tester.scrollUntilVisible(retry, 320);
    await tester.pump();
    expect(find.textContaining('Health data is unavailable right now'),
        findsOneWidget);
    expect(retry, findsOneWidget);

    failStatus = false;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.textContaining('Health data is unavailable right now'),
        findsNothing);
    expect(find.text('Not connected'), findsOneWidget);

    final enable = find.byKey(const ValueKey('advanced-signals-health-enable'));
    await tester.scrollUntilVisible(enable, 320);
    await tester.pump();
    await tester.tap(enable);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
        find.textContaining('Health access was not enabled'), findsOneWidget);
    expect(find.text('Permission off'), findsOneWidget);
    expect(calls, isNot(contains('calendarPermissionStatus')));
    expect(calls, isNot(contains('requestCalendarScheduleHints')));
  });

  testWidgets('authorized without recent data explains the empty state',
      (tester) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'healthPermissionStatus') return 'authorized';
      return null;
    });
    final store = await _buildStore();

    await tester.pumpWidget(
      MaterialApp(home: AdvancedSignalSettingsPage(hintStore: store)),
    );
    await tester.pumpAndSettle();

    final enable = find.byKey(const ValueKey('advanced-signals-health-enable'));
    await tester.scrollUntilVisible(enable, 320);
    await tester.pump();

    expect(find.text('No recent data'), findsOneWidget);
    expect(
      find.textContaining('Permission is enabled, but no recent Health data'),
      findsOneWidget,
    );
    expect(calls, ['healthPermissionStatus']);
    expect(calls, isNot(contains('calendarPermissionStatus')));
  });

  testWidgets('back control closes the pushed Connected insights page',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'healthPermissionStatus') return 'not_requested';
      return null;
    });
    final store = await _buildStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open-advanced-signals'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdvancedSignalSettingsPage(hintStore: store),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-advanced-signals')));
    await tester.pumpAndSettle();
    expect(find.text('Connected insights'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('advanced-signals-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-advanced-signals')), findsOneWidget);
    expect(find.text('Connected insights'), findsNothing);
  });
}

Future<ExternalEnergyHintStore> _buildStore() async {
  await seedMockPrefs();
  final prefs = await SharedPreferences.getInstance();
  return ExternalEnergyHintStore(prefs);
}
