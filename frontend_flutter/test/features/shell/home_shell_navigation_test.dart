import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_opportunity_radar/app/app_router.dart';
import 'package:ai_opportunity_radar/features/shell/home_shell_page.dart';

void main() {
  testWidgets('five-tab shell keeps existing tabs and opens Library',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;

    final router = GoRouter(
      initialLocation: AppRoutes.today,
      routes: [
        ShellRoute(
          builder: (_, __, child) => HomeShellPage(child: child),
          routes: [
            _testRoute(AppRoutes.today, 'today page'),
            _testRoute(AppRoutes.weekly, 'weekly page'),
            _testRoute(AppRoutes.memory, 'journey page'),
            _testRoute(AppRoutes.signalLibrary, 'library page'),
            _testRoute(AppRoutes.me, 'me page'),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Journey'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    expect(find.text('library page'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Journey'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GoRoute _testRoute(String path, String label) {
  return GoRoute(
    path: path,
    builder: (_, __) => Scaffold(body: Center(child: Text(label))),
  );
}
