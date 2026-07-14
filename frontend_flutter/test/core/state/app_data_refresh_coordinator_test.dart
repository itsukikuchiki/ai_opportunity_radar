import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/state/app_data_refresh_coordinator.dart';

void main() {
  test('one mutation is consumed once by every route as it becomes active',
      () async {
    final mutations = StreamController<AppDataMutation>.broadcast(sync: true);
    var todayLoads = 0;
    var weeklyLoads = 0;
    final coordinator = AppDataRefreshCoordinator(
      mutationStream: mutations.stream,
      routeLoaders: {
        '/today': () async => todayLoads += 1,
        '/weekly': () async => weeklyLoads += 1,
      },
    );
    addTearDown(() async {
      coordinator.dispose();
      await mutations.close();
    });

    await coordinator.refreshRoute('/today');
    expect(todayLoads, 0, reason: 'the ViewModel owns its initial load');

    mutations.add(const AppDataMutation(
      kind: AppDataMutationKind.signalCard,
      reason: 'signal_saved',
    ));

    expect(coordinator.isDirty('/today'), isTrue);
    expect(coordinator.isDirty('/weekly'), isTrue);

    await coordinator.refreshRoute('/today');
    await coordinator.refreshRoute('/today');
    await coordinator.refreshRoute('/weekly');

    expect(todayLoads, 1);
    expect(weeklyLoads, 1);
    expect(coordinator.isDirty('/today'), isFalse);
    expect(coordinator.isDirty('/weekly'), isFalse);
  });

  test('concurrent requests share one load and foreground refresh can force it',
      () async {
    final mutations = StreamController<AppDataMutation>.broadcast(sync: true);
    final loadStarted = Completer<void>();
    final finishLoad = Completer<void>();
    var loads = 0;
    final coordinator = AppDataRefreshCoordinator(
      mutationStream: mutations.stream,
      routeLoaders: {
        '/today': () async {
          loads += 1;
          if (loads == 1) {
            loadStarted.complete();
            await finishLoad.future;
          }
        },
      },
    );
    addTearDown(() async {
      coordinator.dispose();
      await mutations.close();
    });

    final first = coordinator.refreshRoute('/today', force: true);
    await loadStarted.future;
    final second = coordinator.refreshRoute('/today', force: true);
    finishLoad.complete();
    await Future.wait([first, second]);

    expect(loads, 1);

    await coordinator.refreshRoute('/today', force: true);
    expect(loads, 2);
  });

  test('default coordinator observes the process mutation bus', () async {
    var loads = 0;
    final coordinator = AppDataRefreshCoordinator(
      routeLoaders: {
        '/me': () async {
          loads += 1;
        },
      },
    );
    addTearDown(coordinator.dispose);

    AppDataMutationBus.publish(
      kind: AppDataMutationKind.externalEnergyHints,
      reason: 'health_hints_changed',
    );
    await coordinator.refreshRoute('/me');

    expect(loads, 1);
  });

  test('a mutation arriving during a load remains dirty for the next refresh',
      () async {
    final mutations = StreamController<AppDataMutation>.broadcast(sync: true);
    final loadStarted = Completer<void>();
    final finishLoad = Completer<void>();
    var loads = 0;
    final coordinator = AppDataRefreshCoordinator(
      mutationStream: mutations.stream,
      routeLoaders: {
        '/today': () async {
          loads += 1;
          if (loads == 1) {
            loadStarted.complete();
            await finishLoad.future;
          }
        },
      },
    );
    addTearDown(() async {
      coordinator.dispose();
      await mutations.close();
    });

    final firstLoad = coordinator.refreshRoute('/today', force: true);
    await loadStarted.future;
    mutations.add(const AppDataMutation(
      kind: AppDataMutationKind.signalCard,
      reason: 'signal_changed_while_loading',
    ));
    finishLoad.complete();
    await firstLoad;

    expect(coordinator.isDirty('/today'), isTrue);
    await coordinator.refreshRoute('/today');
    expect(loads, 2);
    expect(coordinator.isDirty('/today'), isFalse);
  });
}
