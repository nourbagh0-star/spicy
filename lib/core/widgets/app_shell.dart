import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0x1A6B6661), width: 1)),
        ),
        child: NavigationBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          height: 64,
          indicatorColor: AppTheme.primary.withValues(alpha: 0.1),
          selectedIndex: _calculateSelectedIndex(context),
          onDestinationSelected: (index) => _onItemTapped(index, context),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.restaurant_menu_outlined),
              selectedIcon: const Icon(
                Icons.restaurant_menu,
                color: AppTheme.primary,
              ),
              label: locale.menuTitle,
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(
                Icons.receipt_long,
                color: AppTheme.primary,
              ),
              label: locale.orders,
            ),
            NavigationDestination(
              icon: const Icon(Icons.star_outline_rounded),
              selectedIcon: const Icon(
                Icons.star_rounded,
                color: AppTheme.primary,
              ),
              label: locale.reviews,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person, color: AppTheme.primary),
              label: locale.profile,
            ),
          ],
        ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/orders') || location.startsWith('/tracking')) {
      return 1;
    }
    if (location.startsWith('/reviews') || location.startsWith('/review')) {
      return 2;
    }
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/orders');
        break;
      case 2:
        context.go('/reviews');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }
}
