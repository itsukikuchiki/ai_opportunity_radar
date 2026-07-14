import 'dart:async';

import 'package:flutter/foundation.dart';

/// Broad data mutations that can change one or more long-lived page
/// projections. Storage remains the source of truth; this event only marks
/// route projections as needing a refresh.
enum AppDataMutationKind {
  signalCard,
  candidatePlanning,
  focusDomains,
  externalEnergyHints,
  entitlement,
  usage,
}

@immutable
class AppDataMutation {
  final AppDataMutationKind kind;
  final String reason;

  const AppDataMutation({
    required this.kind,
    required this.reason,
  });
}

/// Process-local mutation bridge used by repositories and preference stores.
///
/// It deliberately carries no page state. Consumers always reload from the
/// repositories, so an event cannot become a second source of truth.
class AppDataMutationBus {
  static final StreamController<AppDataMutation> _controller =
      StreamController<AppDataMutation>.broadcast(sync: true);

  static Stream<AppDataMutation> get stream => _controller.stream;

  static void publish({
    required AppDataMutationKind kind,
    required String reason,
  }) {
    if (_controller.isClosed) return;
    _controller.add(AppDataMutation(kind: kind, reason: reason));
  }
}

typedef AppRouteDataLoader = Future<void> Function();

/// Refreshes long-lived page ViewModels when their route becomes active.
///
/// Every mutation increments a shared revision. Each route remembers the last
/// revision it loaded, which means one mutation can refresh Today, Weekly,
/// Journey and Me independently as the user enters them. Concurrent requests
/// for the same route share one in-flight load and therefore cannot create a
/// rebuild/load loop.
class AppDataRefreshCoordinator {
  final Map<String, AppRouteDataLoader> _routeLoaders;
  late final StreamSubscription<AppDataMutation> _mutationSubscription;

  final Map<String, int> _loadedRevisionByRoute = <String, int>{};
  final Map<String, Future<void>> _inFlightByRoute = <String, Future<void>>{};
  int _mutationRevision = 0;
  bool _disposed = false;

  AppDataRefreshCoordinator({
    required Map<String, AppRouteDataLoader> routeLoaders,
    Stream<AppDataMutation>? mutationStream,
  }) : _routeLoaders = Map.unmodifiable(routeLoaders) {
    _mutationSubscription = (mutationStream ?? AppDataMutationBus.stream)
        .listen((_) => _mutationRevision += 1);
  }

  @visibleForTesting
  int get mutationRevision => _mutationRevision;

  @visibleForTesting
  bool isDirty(String route) {
    if (_mutationRevision == 0) return false;
    return (_loadedRevisionByRoute[route] ?? 0) < _mutationRevision;
  }

  /// Refreshes [route] when it has not consumed the latest mutation.
  ///
  /// [force] is reserved for foreground restoration and explicit return flows
  /// such as Signal Library -> Today. The initial route does not reload solely
  /// because the coordinator was constructed; ViewModel constructors already
  /// own that first load.
  Future<void> refreshRoute(
    String route, {
    bool force = false,
  }) async {
    if (_disposed) return;
    final loader = _routeLoaders[route];
    if (loader == null) return;

    final inFlight = _inFlightByRoute[route];
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final requestedRevision = _mutationRevision;
    if (!force) {
      if (requestedRevision == 0) {
        _loadedRevisionByRoute.putIfAbsent(route, () => 0);
        return;
      }
      if ((_loadedRevisionByRoute[route] ?? 0) >= requestedRevision) return;
    }

    late final Future<void> operation;
    operation = Future<void>.sync(loader).then((_) {
      final previous = _loadedRevisionByRoute[route] ?? 0;
      if (requestedRevision > previous) {
        _loadedRevisionByRoute[route] = requestedRevision;
      }
    }).whenComplete(() {
      if (identical(_inFlightByRoute[route], operation)) {
        _inFlightByRoute.remove(route);
      }
    });
    _inFlightByRoute[route] = operation;
    await operation;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_mutationSubscription.cancel());
  }
}
