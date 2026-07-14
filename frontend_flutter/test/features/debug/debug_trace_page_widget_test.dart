import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/debug/legacy_fallback_monitor.dart';
import 'package:ai_opportunity_radar/features/debug/debug_trace_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Debug Trace smoke: dev-only 页面显示 trace 与 fallback counters',
      (tester) async {
    LegacyFallbackMonitor.record(LegacyFallbackMonitor.capturesRawRead);

    await tester.pumpWidget(
      const MaterialApp(
        home: DebugTracePage(
          initialSignalId: 'sig_debug_sample',
          useSampleDataForTest: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DebugTracePage), findsOneWidget);
    expect(find.text('Trace Debug'), findsOneWidget);
    expect(find.text('Legacy fallback counters'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Trace links'),
      find.byType(ListView).first,
      const Offset(0, -260),
    );
    expect(find.text('Trace links'), findsOneWidget);
    expect(find.text('Pipeline runs'), findsOneWidget);
    expect(find.text('Sync identity'), findsOneWidget);
    expect(find.text('Tombstone state'), findsOneWidget);
    expect(find.textContaining('legacy_captures_raw_read_count'), findsWidgets);
    expect(find.textContaining('journey_snapshot'), findsWidgets);
    expect(find.textContaining('client_debug_sample'), findsWidgets);
    expect(find.textContaining('user_deleted'), findsWidgets);
  });
}
