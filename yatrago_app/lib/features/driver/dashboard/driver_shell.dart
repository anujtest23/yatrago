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
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  selected: index == 0,
                  color: AppColors.driver,
                  onTap: () => context.go(RouteNames.driverDashboard),
                ),
                _NavItem(
                  icon: Icons.add_road_rounded,
                  label: 'Post Ride',
                  selected: index == 1,
                  color: AppColors.driver,
                  onTap: () => context.go(RouteNames.postRide),
                ),
                _NavItem(
                  icon: Icons.list_alt_rounded,
                  label: 'My Rides',
                  selected: index == 2,
                  color: AppColors.driver,
                  onTap: () => context.go(RouteNames.driverMyRides),
                ),
                _NavItem(
                  icon: Icons.inbox_rounded,
                  label: 'Bookings',
                  selected: index == 3,
                  color: AppColors.driver,
                  onTap: () => context.go(RouteNames.incomingBookings),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  selected: index == 4,
                  color: AppColors.driver,
                  onTap: () => context.go(RouteNames.driverSettings),
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
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? color : AppColors.textTertiary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
