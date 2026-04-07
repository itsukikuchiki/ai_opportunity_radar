import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../core/i18n/app_locale_text.dart';

class HomeShellPage extends StatelessWidget {
  final Widget child;

  const HomeShellPage({
    super.key,
    required this.child,
  });

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    if (location == AppRoutes.weekly) return 1;
    if (location == AppRoutes.memory) return 2;
    if (location == AppRoutes.me) return 3;
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
        context.go(AppRoutes.memory);
        break;
      case 3:
        context.go(AppRoutes.me);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _selectedIndex(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, -2),
              color: theme.shadowColor.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: NavigationBar(
          height: 72,
          selectedIndex: index,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (value) => _onTap(context, value),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.edit_note_outlined),
              selectedIcon: const Icon(Icons.edit_note),
              label: AppLocaleText.tr(
                context,
                en: 'Today',
                zhHans: 'Today',
                zhHant: 'Today',
                ja: 'Today',
              ),
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights),
              label: AppLocaleText.tr(
                context,
                en: 'Weekly',
                zhHans: 'Weekly',
                zhHant: 'Weekly',
                ja: 'Weekly',
              ),
            ),
            NavigationDestination(
              icon: const Icon(Icons.book_outlined),
              selectedIcon: const Icon(Icons.book),
              label: AppLocaleText.tr(
                context,
                en: 'Journey',
                zhHans: 'Journey',
                zhHant: 'Journey',
                ja: 'Journey',
              ),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: AppLocaleText.tr(
                context,
                en: 'Me',
                zhHans: 'Me',
                zhHant: 'Me',
                ja: 'Me',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
