import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/app_router.dart';
import '../../core/i18n/app_locale_text.dart';
import '../../core/state/app_data_refresh_coordinator.dart';
import '../../shared/widgets/aurora_ui.dart';

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    if (_activeLocation == location) return;
    final isFirstActivation = _activeLocation == null;
    _activeLocation = location;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeLocation != location) return;
      // Long-lived ViewModels already perform their initial load. Every later
      // route activation refreshes once, while the coordinator coalesces a
      // simultaneous explicit return refresh or lifecycle refresh.
      _refreshActiveRoute(force: !isFirstActivation);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
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

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    if (location == AppRoutes.weekly) return 1;
    if (location == AppRoutes.experiment) return 2;
    if (location == AppRoutes.memory) return 3;
    if (location == AppRoutes.me) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.today);
        break;
      case 1:
        context.go(AppRoutes.weekly);
        break;
      case 2:
        context.go(AppRoutes.experiment);
        break;
      case 3:
        context.go(AppRoutes.memory);
        break;
      case 4:
        context.go(AppRoutes.me);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _selectedIndex(context);

    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            height: MediaQuery.textScalerOf(context).scale(12) > 14 ? 78 : 72,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFFFBF7).withValues(alpha: 0.94),
                  const Color(0xFFF4F1FF).withValues(alpha: 0.92),
                  const Color(0xFFEDF5FF).withValues(alpha: 0.94),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFFDCDDF0).withValues(alpha: 0.64),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                  color: AuroraColors.purple.withValues(alpha: 0.14),
                ),
              ],
            ),
            child: Row(
              children: [
                _NavPill(
                  selected: index == 0,
                  icon: Icons.chat_bubble_outline_rounded,
                  selectedIcon: Icons.chat_bubble_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Today',
                    zhHans: '今天',
                    zhHant: '今天',
                    ja: '今日',
                  ),
                  onTap: () => _onTap(context, 0),
                ),
                _NavPill(
                  selected: index == 1,
                  icon: Icons.calendar_month_outlined,
                  selectedIcon: Icons.calendar_month_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Weekly',
                    zhHans: '每周复盘',
                    zhHant: '每週',
                    ja: 'Weekly',
                  ),
                  onTap: () => _onTap(context, 1),
                ),
                _NavPill(
                  selected: index == 2,
                  icon: Icons.science_outlined,
                  selectedIcon: Icons.science_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Experiment',
                    zhHans: '生活小实验',
                    zhHant: '小實驗',
                    ja: '実験',
                  ),
                  onTap: () => _onTap(context, 2),
                ),
                _NavPill(
                  selected: index == 3,
                  icon: Icons.location_on_outlined,
                  selectedIcon: Icons.location_on_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Journey',
                    zhHans: '旅程',
                    zhHant: '旅程',
                    ja: 'Journey',
                  ),
                  onTap: () => _onTap(context, 3),
                ),
                _NavPill(
                  selected: index == 4,
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Me',
                    zhHans: '我的',
                    zhHant: '我的',
                    ja: 'マイ',
                  ),
                  onTap: () => _onTap(context, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  const _NavPill({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        onTap: onTap,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          selected ? AuroraColors.purple : Colors.transparent,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color:
                                    AuroraColors.purple.withValues(alpha: 0.30),
                                blurRadius: 18,
                                offset: const Offset(0, 7),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      selected ? selectedIcon : icon,
                      size: 22,
                      color: selected ? Colors.white : const Color(0xFF9A9CAF),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected
                              ? AuroraColors.purple
                              : const Color(0xFF858895),
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
