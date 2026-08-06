import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/app_router.dart';
import '../../core/notifications/schedule_notification_service.dart';
import '../../core/state/app_data_refresh_coordinator.dart';
import '../pages/today/today_view_model.dart';
import 'main_tab_bottom_navigation.dart';

class HomeShellPage extends StatefulWidget {
  final Widget child;

  const HomeShellPage({
    super.key,
    required this.child,
  });

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage>
    with WidgetsBindingObserver {
  String? _activeLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_routeSignalReminderToTodayIfNeeded());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    if (_activeLocation == location) return;
    final previousLocation = _activeLocation;
    final isFirstActivation = previousLocation == null;
    _activeLocation = location;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeLocation != location) return;
      if (!isFirstActivation &&
          location == AppRoutes.today &&
          previousLocation != AppRoutes.today) {
        Provider.of<TodayViewModel?>(context, listen: false)
            ?.resetAiJudgementPageSession();
      }
      // Long-lived ViewModels already perform their initial load. Every later
      // route activation refreshes once, while the coordinator coalesces a
      // simultaneous explicit return refresh or lifecycle refresh.
      _refreshActiveRoute(force: !isFirstActivation);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_routeSignalReminderToTodayIfNeeded());
    _refreshActiveRoute(force: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _refreshActiveRoute({bool force = false}) {
    final location = _activeLocation;
    if (location == null || !mounted) return;
    final coordinator =
        Provider.of<AppDataRefreshCoordinator?>(context, listen: false);
    if (coordinator == null) return;
    unawaited(coordinator.refreshRoute(location, force: force));
  }

  Future<void> _routeSignalReminderToTodayIfNeeded() async {
    final openToday =
        await ScheduleNotificationService().consumeTodayDestination();
    if (!openToday || !mounted) return;
    context.go(AppRoutes.today);
  }

  int _selectedIndex(BuildContext context) {
    // A primary destination can be pushed from another primary tab (for
    // example Today -> "View all" -> Life Experiment). In that case the
    // inherited GoRouterState below the retained shell can still describe the
    // previous page. The router delegate always exposes the visible top-level
    // location, so the selected tab follows what the user is actually seeing.
    final location = GoRouter.of(context)
        .routerDelegate
        .currentConfiguration
        .last
        .matchedLocation;

    if (location == AppRoutes.weekly) return 1;
    if (location == AppRoutes.experiment) return 2;
    if (location == AppRoutes.memory) return 3;
    if (location == AppRoutes.me) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _selectedIndex(context);

    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: MainTabBottomNavigation(selectedIndex: index),
    );
  }
}
