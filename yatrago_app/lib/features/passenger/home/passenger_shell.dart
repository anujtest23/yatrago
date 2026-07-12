import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../shared/chat/chat_unread.dart';

class PassengerShell extends StatelessWidget {
  final Widget child;
  const PassengerShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(RouteNames.passengerHome)) return 0;
    if (location.startsWith(RouteNames.search)) return 1;
    if (location.startsWith(RouteNames.passengerMyRides)) return 2;
    if (location.startsWith(RouteNames.passengerMessages)) return 3;
    if (location.startsWith(RouteNames.notifications)) return 4;
    if (location.startsWith(RouteNames.settings)) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  activeIcon: Icons.home_rounded,
                  inactiveIcon: Icons.home_outlined,
                  label: 'Home',
                  selected: index == 0,
                  onTap: () => context.go(RouteNames.passengerHome),
                ),
                _NavItem(
                  activeIcon: Icons.search_rounded,
                  inactiveIcon: Icons.search_outlined,
                  label: 'Search',
                  selected: index == 1,
                  onTap: () => context.go(RouteNames.search),
                ),
                _NavItem(
                  activeIcon: Icons.confirmation_number_rounded,
                  inactiveIcon: Icons.confirmation_number_outlined,
                  label: 'My Rides',
                  selected: index == 2,
                  onTap: () => context.go(RouteNames.passengerMyRides),
                ),
                _NavItem(
                  activeIcon: Icons.chat_bubble_rounded,
                  inactiveIcon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  selected: index == 3,
                  badgeListenable: ChatUnread.instance,
                  onTap: () => context.go(RouteNames.passengerMessages),
                ),
                _NavItem(
                  activeIcon: Icons.notifications_rounded,
                  inactiveIcon: Icons.notifications_outlined,
                  label: 'Alerts',
                  selected: index == 4,
                  onTap: () => context.go(RouteNames.notifications),
                ),
                _NavItem(
                  activeIcon: Icons.person_rounded,
                  inactiveIcon: Icons.person_outline_rounded,
                  label: 'Profile',
                  selected: index == 5,
                  onTap: () => context.go(RouteNames.settings),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ChatUnread? badgeListenable;

  const _NavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeListenable,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : const Color(0xFF94A3B8);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IconWithBadge(
            icon: Icon(selected ? activeIcon : inactiveIcon,
                size: 24, color: color),
            badgeListenable: badgeListenable,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: selected ? 24 : 0,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlays a live unread-count badge on a nav icon. Rebuilds only when the
/// [ChatUnread] counter changes.
class _IconWithBadge extends StatelessWidget {
  final Widget icon;
  final ChatUnread? badgeListenable;

  const _IconWithBadge({required this.icon, this.badgeListenable});

  @override
  Widget build(BuildContext context) {
    if (badgeListenable == null) return icon;
    return AnimatedBuilder(
      animation: badgeListenable!,
      builder: (context, _) {
        final count = badgeListenable!.count;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            if (count > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
