import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notification_router.dart';
import '../core/responsive/responsive.dart';
import '../features/patient/presentation/providers/patient_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/exit_app_scope.dart';
import '../widgets/in_app_notification_overlay.dart';
import 'home_screen.dart';
import 'placeholder_screens.dart' show ProfileScreen;
import 'schedule_screen.dart';
import 'messages_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    NotificationRouter.registerTabSwitcher((tabIndex) {
      if (mounted) {
        setState(() => _index = tabIndex);
      }
    });
    NotificationRouter.registerAppointmentRefresher(() {
      ref.invalidate(appointmentsProvider);
      ref.invalidate(dashboardProvider);
    });
  }

  @override
  void dispose() {
    NotificationRouter.unregisterTabSwitcher();
    NotificationRouter.unregisterAppointmentRefresher();
    super.dispose();
  }

  static const _destinations = [
    _NavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavDestination(
      label: 'Schedule',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    _NavDestination(
      label: 'Messages',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
    ),
    _NavDestination(
      label: 'Me',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  void _onTabSelected(int value) {
    if (value == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final pages = [
      HomeScreen(onNavigateToTab: _onTabSelected),
      const ScheduleScreen(),
      const MessagesScreen(),
      const ProfileScreen(),
    ];

    // Keep every tab mounted so scroll position, drafts, and loaded data remain
    // stable while navigating. This feels faster than rebuilding a page per tap.
    final body = IndexedStack(index: _index, children: pages);

    return ExitAppScope(
      child: InAppNotificationOverlay(
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: responsive.useNavigationRail
              ? Row(
                  children: [
                    _AppNavigationRail(
                      index: _index,
                      extended: responsive.width >= 1024,
                      onChanged: _onTabSelected,
                    ),
                    const VerticalDivider(width: 1, color: AppColors.border),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: responsive.useNavigationRail
              ? null
              : _AppBottomNav(index: _index, onChanged: _onTabSelected),
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _AppNavigationRail extends StatelessWidget {
  const _AppNavigationRail({
    required this.index,
    required this.extended,
    required this.onChanged,
  });

  final int index;
  final bool extended;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      extended: extended,
      minExtendedWidth: 180,
      backgroundColor: AppColors.surface,
      selectedIndex: index,
      onDestinationSelected: onChanged,
      labelType: extended ? null : NavigationRailLabelType.all,
      selectedIconTheme: const IconThemeData(color: AppColors.primary),
      unselectedIconTheme: const IconThemeData(color: AppColors.iconMuted),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AppColors.iconMuted,
        fontWeight: FontWeight.w500,
      ),
      destinations: [
        for (final item in _MainShellState._destinations)
          NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: Text(item.label),
          ),
      ],
    );
  }
}

class _AppBottomNav extends StatelessWidget {
  const _AppBottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final destinations = _MainShellState._destinations;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            responsive.rz(10),
            responsive.rz(8),
            responsive.rz(10),
            responsive.rz(8),
          ),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                _NavItem(
                  selected: index == i,
                  icon: destinations[i].selectedIcon,
                  outlinedIcon: destinations[i].icon,
                  label: destinations[i].label,
                  onTap: () => onChanged(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final color = selected ? AppColors.primary : AppColors.iconMuted;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label tab',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(vertical: responsive.rz(8)),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryMuted : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.08 : 1,
                    duration: duration,
                    curve: Curves.easeOutBack,
                    child: AnimatedSwitcher(
                      duration: duration,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.85, end: 1).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutBack,
                              ),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        selected ? icon : outlinedIcon,
                        key: ValueKey(selected),
                        color: color,
                        size: responsive.bottomNavIconSize,
                      ),
                    ),
                  ),
                  SizedBox(height: responsive.rz(4)),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: responsive.bottomNavLabelSize,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
