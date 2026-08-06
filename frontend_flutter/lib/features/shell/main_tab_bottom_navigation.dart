import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../core/i18n/app_locale_text.dart';
import '../../shared/widgets/aurora_ui.dart';

/// The single visual and interaction contract for the five primary tabs.
///
/// Secondary pages that intentionally keep the primary navigation visible
/// must reuse this widget instead of maintaining a local copy.
class MainTabBottomNavigation extends StatelessWidget {
  static const navigationKey = ValueKey<String>('main-tab-bottom-navigation');

  final int selectedIndex;

  const MainTabBottomNavigation({
    super.key,
    required this.selectedIndex,
  });

  static String routeForIndex(int index) {
    return switch (index) {
      1 => AppRoutes.weekly,
      2 => AppRoutes.experiment,
      3 => AppRoutes.memory,
      4 => AppRoutes.me,
      _ => AppRoutes.today,
    };
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      _MainTabDestination(
        icon: Icons.chat_bubble_outline_rounded,
        selectedIcon: Icons.chat_bubble_rounded,
        label: AppLocaleText.tr(
          context,
          en: 'Today',
          zhHans: '今天',
          zhHant: '今天',
          ja: '今日',
        ),
      ),
      _MainTabDestination(
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
        label: AppLocaleText.tr(
          context,
          en: 'Weekly',
          zhHans: '每周复盘',
          zhHant: '每週復盤',
          ja: '週間レビュー',
        ),
      ),
      _MainTabDestination(
        icon: Icons.science_outlined,
        selectedIcon: Icons.science_rounded,
        label: AppLocaleText.tr(
          context,
          en: 'Experiments',
          zhHans: '生活小实验',
          zhHant: '生活小實驗',
          ja: '生活実験',
        ),
      ),
      _MainTabDestination(
        icon: Icons.location_on_outlined,
        selectedIcon: Icons.location_on_rounded,
        label: AppLocaleText.tr(
          context,
          en: 'Journey',
          zhHans: '旅程',
          zhHant: '旅程',
          ja: '旅程',
        ),
      ),
      _MainTabDestination(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: AppLocaleText.tr(
          context,
          en: 'Me',
          zhHans: '我的',
          zhHant: '我的',
          ja: 'マイ',
        ),
      ),
    ];

    return SafeArea(
      key: navigationKey,
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
              for (var index = 0; index < destinations.length; index++)
                _MainTabPill(
                  selected: selectedIndex == index,
                  destination: destinations[index],
                  onTap: () => context.go(routeForIndex(index)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainTabPill extends StatelessWidget {
  final bool selected;
  final _MainTabDestination destination;
  final VoidCallback onTap;

  const _MainTabPill({
    required this.selected,
    required this.destination,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isJapanese = Localizations.localeOf(context).languageCode == 'ja';
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
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
                      selected ? destination.selectedIcon : destination.icon,
                      size: 22,
                      color: selected ? Colors.white : const Color(0xFF9A9CAF),
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: double.infinity,
                    height: 15,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: selected
                                  ? AuroraColors.purple
                                  : const Color(0xFF858895),
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: isJapanese ? 10 : 11,
                            ),
                      ),
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

class _MainTabDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _MainTabDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
