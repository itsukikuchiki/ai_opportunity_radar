import 'package:ai_opportunity_radar/core/navigation/app_back_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('secondary route returns to the actual previous route',
      (tester) async {
    final router = _router('/origin');
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open secondary'));
    await tester.pumpAndSettle();
    expect(find.text('Secondary'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Origin'), findsOneWidget);
    expect(find.text('Fallback'), findsNothing);
  });

  testWidgets('direct secondary route uses its safe fallback', (tester) async {
    final router = _router('/secondary');
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Secondary'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Fallback'), findsOneWidget);
  });
}

GoRouter _router(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/origin',
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              const Text('Origin'),
              TextButton(
                onPressed: () => context.push('/secondary'),
                child: const Text('Open secondary'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/secondary',
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              const Text('Secondary'),
              TextButton(
                onPressed: () => context.popOrGo('/fallback'),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/fallback',
        builder: (context, state) => const Scaffold(
          body: Text('Fallback'),
        ),
      ),
    ],
  );
}
