import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:spicy/core/widgets/app_shell.dart';
import 'package:spicy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:spicy/features/auth/presentation/cubit/auth_state.dart';
import 'package:spicy/features/auth/presentation/screens/welcome_screen.dart';
import 'package:spicy/features/auth/presentation/screens/login_screen.dart';
import 'package:spicy/features/auth/presentation/screens/register_screen.dart';
import 'package:spicy/features/menu/presentation/screens/menu_screen.dart';
import 'package:spicy/features/menu/presentation/screens/product_detail_screen.dart';
import 'package:spicy/features/cart/presentation/screens/cart_screen.dart';
import 'package:spicy/features/cart/presentation/screens/checkout_screen.dart';
import 'package:spicy/features/order_tracking/presentation/screens/order_tracking_screen.dart';
import 'package:spicy/features/order_tracking/presentation/screens/orders_screen.dart';
import 'package:spicy/features/reviews/presentation/screens/reviews_screen.dart';
import 'package:spicy/features/reviews/presentation/screens/leave_review_screen.dart';
import 'package:spicy/features/reviews/presentation/screens/rate_order_items_screen.dart';
import 'package:spicy/features/profile/presentation/screens/profile_screen.dart';
import 'package:spicy/features/owner/presentation/screens/owner_dashboard_screen.dart';
import 'package:spicy/features/owner/presentation/screens/owner_management_screens.dart';
import 'package:spicy/features/manager/presentation/screens/manager_dashboard_screen.dart';
import 'package:spicy/features/manager/presentation/screens/manager_menu_availability_screen.dart';
import 'package:spicy/features/manager/presentation/screens/manager_order_detail_screen.dart';
import 'package:spicy/features/delivery/presentation/screens/delivery_management_screen.dart';

class AppRouterController {
  final GoRouter router;
  final _AuthRefreshNotifier _authRefreshNotifier;

  const AppRouterController._(this.router, this._authRefreshNotifier);

  void dispose() {
    router.dispose();
    _authRefreshNotifier.dispose();
  }
}

AppRouterController createAppRouter(AuthCubit authCubit) {
  final authRefreshNotifier = _AuthRefreshNotifier(authCubit);
  final router = GoRouter(
    initialLocation: '/welcome',
    refreshListenable: authRefreshNotifier,
    redirect: (context, state) {
      final isAuthenticated =
          authCubit.state.status == AuthStatus.authenticated;
      final isOnAuthPage =
          state.uri.toString() == '/welcome' ||
          state.uri.toString() == '/login' ||
          state.uri.toString() == '/register';

      final isOwner = authCubit.state.user.isOwner;
      final isManager = authCubit.state.user.isManager;
      final isOnOwnerPage = state.uri.path.startsWith('/owner');
      final isOnManagerPage = state.uri.path.startsWith('/manager');

      // If authenticated and trying to visit auth pages, redirect to home
      if (isAuthenticated && isOnAuthPage) {
        if (isOwner) return '/owner';
        if (isManager) return '/manager';
        return '/';
      }

      // If not authenticated and trying to visit protected pages, redirect to welcome
      if (!isAuthenticated && !isOnAuthPage) {
        return '/welcome';
      }

      if (isAuthenticated &&
          isOwner &&
          !isOnOwnerPage &&
          state.uri.path == '/') {
        return '/owner';
      }

      if (isAuthenticated && !isOwner && isOnOwnerPage) return '/';
      if (isAuthenticated &&
          isManager &&
          !isOnManagerPage &&
          state.uri.path == '/') {
        return '/manager';
      }
      if (isAuthenticated && !isManager && isOnManagerPage) return '/';

      return null;
    },
    routes: [
      // Auth routes (no bottom nav)
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: '/owner/menu',
        builder: (context, state) => const OwnerMenuScreen(),
      ),
      GoRoute(
        path: '/owner/modifiers',
        builder: (context, state) => const OwnerModifiersScreen(),
      ),
      GoRoute(
        path: '/owner/branches',
        builder: (context, state) => const OwnerBranchesScreen(),
      ),
      GoRoute(
        path: '/owner/delivery',
        builder: (context, state) =>
            const DeliveryManagementScreen(isOwner: true),
      ),
      GoRoute(
        path: '/manager',
        builder: (context, state) => const ManagerDashboardScreen(),
      ),
      GoRoute(
        path: '/manager/menu',
        builder: (context, state) => const ManagerMenuAvailabilityScreen(),
      ),
      GoRoute(
        path: '/manager/delivery',
        builder: (context, state) =>
            const DeliveryManagementScreen(isOwner: false),
      ),
      GoRoute(
        path: '/manager/order/:orderId',
        builder: (context, state) =>
            ManagerOrderDetailScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Customer tabs intentionally use the root Navigator. A ShellRoute adds a
      // second Navigator, which can reserve the same page key twice when the
      // checkout flow returns to a tab (for example checkout -> profile).
      // Wrapping each tab in the shared shell preserves the bottom navigation
      // without introducing a nested navigation stack.
      GoRoute(
        path: '/',
        builder: (context, state) => const AppShell(child: MenuScreen()),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const AppShell(child: OrdersScreen()),
      ),
      GoRoute(
        path: '/reviews',
        builder: (context, state) => const AppShell(child: ReviewsScreen()),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const AppShell(child: ProfileScreen()),
      ),

      // Routes without bottom nav (pushed on top, protected)
      GoRoute(
        path: '/product/:id',
        builder: (context, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/tracking/:orderId',
        builder: (context, state) =>
            OrderTrackingScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: '/review/new',
        builder: (context, state) => LeaveReviewScreen(
          orderId: state.uri.queryParameters['orderId'] ?? '',
          branchId: state.uri.queryParameters['branchId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/review/items',
        builder: (context, state) => RateOrderItemsScreen(
          orderId: state.uri.queryParameters['orderId'] ?? '',
        ),
      ),
    ],
  );
  return AppRouterController._(router, authRefreshNotifier);
}

/// Notifies GoRouter to re-evaluate routes when auth state changes.
class _AuthRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  _AuthRefreshNotifier(AuthCubit authCubit) {
    _subscription = authCubit.stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
