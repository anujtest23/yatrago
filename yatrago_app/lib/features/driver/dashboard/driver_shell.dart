import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';

class DriverShell extends StatelessWidget {
  final Widget child;
  const DriverShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(RouteNames.driverDashboard)) return 0;
    if (location.startsWith(RouteNames.postRide)) return 1;
    if (location.startsWith(RouteNames.driverMyRides)) return 2;
    if (location.startsWith(RouteNames.incomingBookings)) return 3;
    if (location.startsWith(RouteNames.driverSettings)) return 4;
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
              icon: Icons.person_rounded,
              label: 'Profile',
              selected: index == 4,
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

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
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
            Icon(
              icon,
              size: 22,
              color: selected ? Colors.white : AppColors.textTertiary,
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
