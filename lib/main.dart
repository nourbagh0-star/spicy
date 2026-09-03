import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spicy/core/config/app_environment.dart';
import 'package:spicy/core/error/error_handler.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/theme/app_theme_controller.dart';
import 'package:spicy/core/router/app_router.dart';
import 'package:spicy/core/widgets/app_error_view.dart';

import 'package:spicy/core/locale/app_locale.dart';

// Repositories
import 'package:spicy/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:spicy/features/branch/data/repositories/supabase_branch_repository.dart';
import 'package:spicy/features/menu/data/datasources/supabase_menu_data_source.dart';
import 'package:spicy/features/menu/data/repositories/menu_repository_impl.dart';
import 'package:spicy/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:spicy/features/order_tracking/data/repositories/order_repository_impl.dart';
import 'package:spicy/features/reviews/data/repositories/review_repository_impl.dart';
import 'package:spicy/features/reviews/data/datasources/supabase_review_data_source.dart';
import 'package:spicy/features/profile/data/repositories/profile_repository_impl.dart';

// Cubits
import 'package:spicy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:spicy/features/menu/presentation/cubit/menu_cubit.dart';
import 'package:spicy/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:spicy/features/order_tracking/presentation/cubit/order_tracking_cubit.dart';
import 'package:spicy/features/reviews/presentation/cubit/reviews_cubit.dart';
import 'package:spicy/features/profile/presentation/cubit/profile_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorHandler.initialize();

  if (AppEnvironment.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppEnvironment.supabaseUrl,
      publishableKey: AppEnvironment.supabasePublishableKey,
    );
  }

  final supabaseClient = AppEnvironment.isSupabaseConfigured
      ? Supabase.instance.client
      : null;
  final appLocale = AppLocale(client: supabaseClient);
  final themeController = AppThemeController();

  // Create repositories (singleton instances)
  final authRepository = AuthRepositoryImpl(client: supabaseClient);
  final branchRepository = SupabaseBranchRepository(client: supabaseClient);
  final menuDataSource = SupabaseMenuDataSource(
    client: supabaseClient,
    locale: appLocale,
  );
  final menuRepository = MenuRepositoryImpl(dataSource: menuDataSource);
  final cartRepository = CartRepositoryImpl();
  final orderRepository = OrderRepositoryImpl(
    client: supabaseClient,
    locale: appLocale,
  );
  final reviewRepository = ReviewRepositoryImpl(
    dataSource: SupabaseReviewDataSource(client: supabaseClient),
  );
  final profileRepository = ProfileRepositoryImpl(client: supabaseClient);

  // Create AuthCubit first (needed for router)
  final authCubit = AuthCubit(repository: authRepository);
  await authCubit.restoreSession();
  try {
    await appLocale.loadSavedLocale();
  } catch (error) {
    debugPrint('Could not load the saved language preference: $error');
  }
  await themeController.load();

  runApp(
    MultiRepositoryProvider(
      providers: [
        ChangeNotifierProvider<AppLocale>.value(value: appLocale),
        ChangeNotifierProvider<AppThemeController>.value(
          value: themeController,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<BranchCubit>(
            create: (_) => BranchCubit(repository: branchRepository),
          ),
          BlocProvider<MenuCubit>(
            create: (_) => MenuCubit(repository: menuRepository),
          ),
          BlocProvider<CartCubit>(
            create: (_) => CartCubit(repository: cartRepository)..loadCart(),
          ),
          BlocProvider<OrderTrackingCubit>(
            create: (_) => OrderTrackingCubit(repository: orderRepository),
          ),
          BlocProvider<ReviewsCubit>(
            create: (_) => ReviewsCubit(repository: reviewRepository),
          ),
          BlocProvider<ProfileCubit>(
            create: (_) => ProfileCubit(repository: profileRepository),
          ),
        ],
        child: EpicureanHarmonyApp(
          authCubit: authCubit,
          locale: appLocale,
          themeController: themeController,
        ),
      ),
    ),
  );
}

class EpicureanHarmonyApp extends StatefulWidget {
  final AuthCubit authCubit;
  final AppLocale locale;
  final AppThemeController themeController;

  const EpicureanHarmonyApp({
    super.key,
    required this.authCubit,
    required this.locale,
    required this.themeController,
  });

  @override
  State<EpicureanHarmonyApp> createState() => _EpicureanHarmonyAppState();
}

class _EpicureanHarmonyAppState extends State<EpicureanHarmonyApp> {
  late final AppRouterController _routerController;

  @override
  void initState() {
    super.initState();
    _routerController = createAppRouter(widget.authCubit);
  }

  @override
  void dispose() {
    _routerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.locale, widget.themeController]),
      builder: (context, child) {
        return MaterialApp.router(
          title: widget.locale.appName,
          locale: widget.locale.locale,
          supportedLocales: AppLocale.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: widget.themeController.themeMode,
          routerConfig: _routerController.router,
          builder: (context, child) {
            if (kReleaseMode) {
              ErrorWidget.builder = (details) =>
                  AppErrorView(error: details.exception, compact: true);
            }
            return child ??
                AppErrorView(
                  error: StateError('The application could not be rendered.'),
                );
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
