import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';

class PassengerShell extends StatelessWidget {
  final Widget child;
  const PassengerShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(RouteNames.passengerHome)) return 0;
    if (location.startsWith(RouteNames.search)) return 1;
    if (location.startsWith(RouteNames.passengerMyRides)) return 2;
    if (location.startsWith(RouteNames.notifications)) return 3;
    if (location.startsWith(RouteNames.settings)) return 4;
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
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: index == 0,
                  onTap: () => context.go(RouteNames.passengerHome),
                ),
                _NavItem(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  selected: index == 1,
                  onTap: () => context.go(RouteNames.search),
                ),
                _NavItem(
                  icon: Icons.confirmation_number_rounded,
                  label: 'My Rides',
                  selected: index == 2,
                  onTap: () => context.go(RouteNames.passengerMyRides),
                ),
                _NavItem(
                  icon: Icons.notifications_rounded,
                  label: 'Alerts',
                  selected: index == 3,
                  onTap: () => context.go(RouteNames.notifications),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  selected: index == 4,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
