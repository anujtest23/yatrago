import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../shared/chat/chat_unread.dart';

class DriverShell extends StatelessWidget {
  final Widget child;
  const DriverShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(RouteNames.driverDashboard)) return 0;
    if (location.startsWith(RouteNames.postRide)) return 1;
    if (location.startsWith(RouteNames.driverMyRides)) return 2;
    if (location.startsWith(RouteNames.incomingBookings)) return 3;
    if (location.startsWith(RouteNames.driverMessages)) return 4;
    if (location.startsWith(RouteNames.driverSettings)) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: AppColors.driver.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              selected: index == 0,
              onTap: () => context.go(RouteNames.driverDashboard),
            ),
            _NavItem(
              icon: Icons.add_road_rounded,
              label: 'Post Ride',
              selected: index == 1,
              onTap: () => context.go(RouteNames.postRide),
            ),
            _NavItem(
              icon: Icons.list_alt_rounded,
              label: 'My Rides',
              selected: index == 2,
              onTap: () => context.go(RouteNames.driverMyRides),
            ),
            _NavItem(
              icon: Icons.inbox_rounded,
              label: 'Bookings',
              selected: index == 3,
              onTap: () => context.go(RouteNames.incomingBookings),
            ),
            _NavItem(
              icon: Icons.chat_bubble_rounded,
              label: 'Chat',
              selected: index == 4,
              badgeListenable: ChatUnread.instance,
              onTap: () => context.go(RouteNames.driverMessages),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              selected: index == 5,
              onTap: () => context.go(RouteNames.driverSettings),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ChatUnread? badgeListenable;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeListenable,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 12),
        height: 48,
        decoration: BoxDecoration(
          gradient: selected
              ? AppColors.driverGradient
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.driver.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconWithBadge(
              badgeListenable: badgeListenable,
              icon: Icon(
                icon,
                size: 22,
                color: selected ? Colors.white : AppColors.textTertiary,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Overlays a live unread-count dot on a nav icon, rebuilding only when the
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error,
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
