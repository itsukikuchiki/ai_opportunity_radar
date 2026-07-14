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
      'Advanced Signals smoke: only health recovery hints remain and raw data stays hidden',
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

    expect(find.text('Advanced signal settings'), findsOneWidget);
    expect(find.textContaining('abstract recovery signals'), findsOneWidget);
    expect(find.text('Calendar schedule density'), findsNothing);
    expect(find.text('Health recovery signals'), findsOneWidget);
    expect(
        find.textContaining('Private medical recovery session'), findsNothing);
    expect(calls, ['healthPermissionStatus']);

    final refresh = AppDataMutationBus.stream.firstWhere(
      (mutation) => mutation.reason == 'health_energy_hints_changed',
    );
    final enable = find.byKey(const ValueKey('advanced-signals-health-enable'));
    await tester.ensureVisible(enable);
    await tester.pump();
    await tester.tap(enable);
    await tester.pumpAndSettle();
    expect((await refresh.timeout(const Duration(seconds: 2))).kind,
        AppDataMutationKind.externalEnergyHints);

    expect(find.text('In use'), findsOneWidget);
    expect(find.text('Refresh hints'), findsOneWidget);
    expect(find.text('Clear saved hints'), findsOneWidget);
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

    expect(find.textContaining('Persisted abstract recovery hint'),
        findsOneWidget);
    expect(find.textContaining('must never be shown'), findsNothing);
    expect(find.text('In use'), findsOneWidget);

    final refresh = AppDataMutationBus.stream.firstWhere(
      (mutation) => mutation.reason == 'health_energy_hints_cleared',
    );
    final clear = find.byKey(const ValueKey('advanced-signals-health-clear'));
    await tester.ensureVisible(clear);
    await tester.pump();
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect((await refresh.timeout(const Duration(seconds: 2))).kind,
        AppDataMutationKind.externalEnergyHints);

    expect(store.loadHealthSummary().hasAnyHint, isFalse);
    expect(find.textContaining('Saved recovery hints were removed'),
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
    expect(find.textContaining('unavailable right now'), findsOneWidget);
    expect(find.byKey(const ValueKey('advanced-signals-health-retry')),
        findsOneWidget);

    failStatus = false;
    final retry = find.byKey(const ValueKey('advanced-signals-health-retry'));
    await tester.ensureVisible(retry);
    await tester.pump();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.textContaining('unavailable right now'), findsNothing);
    expect(find.text('Not enabled yet'), findsOneWidget);

    final enable = find.byKey(const ValueKey('advanced-signals-health-enable'));
    await tester.ensureVisible(enable);
    await tester.pump();
    await tester.tap(enable);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
        find.textContaining('Health access was not enabled'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(calls, isNot(contains('calendarPermissionStatus')));
    expect(calls, isNot(contains('requestCalendarScheduleHints')));
  });

  testWidgets('back control closes the pushed Advanced Signals page',
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
    expect(find.text('Advanced signal settings'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('advanced-signals-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-advanced-signals')), findsOneWidget);
    expect(find.text('Advanced signal settings'), findsNothing);
  });
}

Future<ExternalEnergyHintStore> _buildStore() async {
  await seedMockPrefs();
  final prefs = await SharedPreferences.getInstance();
  return ExternalEnergyHintStore(prefs);
}
