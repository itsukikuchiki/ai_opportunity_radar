import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../core/i18n/app_locale_text.dart';
import '../../shared/widgets/aurora_ui.dart';

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
    if (location == AppRoutes.signalLibrary) return 3;
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
        context.go(AppRoutes.memory);
        break;
      case 3:
        context.go(AppRoutes.signalLibrary);
        break;
      case 4:
        context.go(AppRoutes.me);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _selectedIndex(context);
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white),
              boxShadow: [
                BoxShadow(
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                  color: theme.shadowColor.withValues(alpha: 0.10),
                ),
              ],
            ),
            child: Row(
              children: [
                _NavPill(
                  selected: index == 0,
                  icon: Icons.wb_sunny_outlined,
                  selectedIcon: Icons.wb_sunny,
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
                  icon: Icons.bar_chart_rounded,
                  selectedIcon: Icons.bar_chart_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Weekly',
                    zhHans: '洞察',
                    zhHant: '洞察',
                    ja: '洞察',
                  ),
                  onTap: () => _onTap(context, 1),
                ),
                _NavPill(
                  selected: index == 2,
                  icon: Icons.history_rounded,
                  selectedIcon: Icons.history_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Journey',
                    zhHans: '回顾',
                    zhHant: '回顧',
                    ja: '回顧',
                  ),
                  onTap: () => _onTap(context, 2),
                ),
                _NavPill(
                  selected: index == 3,
                  icon: Icons.menu_book_outlined,
                  selectedIcon: Icons.menu_book,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Library',
                    zhHans: '信号库',
                    zhHant: '信號庫',
                    ja: 'ライブラリ',
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          decoration: BoxDecoration(
            color: selected
                ? AuroraColors.purple.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 18,
                color: selected ? AuroraColors.purple : const Color(0xFF858895),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected
                          ? AuroraColors.purple
                          : const Color(0xFF858895),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
