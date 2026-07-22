import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Consistent back behavior for full-screen routes.
///
/// A route reached through normal in-app navigation returns to its real caller.
/// A route opened directly (for example from a deep link or a QA initial route)
/// has no history entry, so it falls back to the owning module's safe entry.
extension AppBackNavigation on BuildContext {
  void popOrGo<T extends Object?>(String fallbackLocation, [T? result]) {
    final router = GoRouter.maybeOf(this);
    if (router != null) {
      if (router.canPop()) {
        router.pop<T>(result);
      } else {
        router.go(fallbackLocation);
      }
      return;
    }

    // Some reusable secondary pages are also hosted by a plain Navigator in
    // widget tests and embedders. Falling back to Navigator keeps the same
    // "return to the real caller" contract without requiring a GoRouter
    // ancestor merely to close a pushed page.
    final navigator = Navigator.maybeOf(this);
    if (navigator?.canPop() ?? false) {
      navigator!.pop<T>(result);
    }
  }
}
