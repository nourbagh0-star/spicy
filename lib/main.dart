import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spicy/core/config/app_environment.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/router/app_router.dart';

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
  final profileRepository = ProfileRepositoryImpl();

  // Create AuthCubit first (needed for router)
  final authCubit = AuthCubit(repository: authRepository);
  await authCubit.restoreSession();
  try {
    await appLocale.loadSavedLocale();
  } catch (error) {
    debugPrint('Could not load the saved language preference: $error');
  }

  runApp(
    MultiRepositoryProvider(
      providers: [ChangeNotifierProvider<AppLocale>.value(value: appLocale)],
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
        child: EpicureanHarmonyApp(authCubit: authCubit, locale: appLocale),
      ),
    ),
  );
}

class EpicureanHarmonyApp extends StatelessWidget {
  final AuthCubit authCubit;
  final AppLocale locale;

  const EpicureanHarmonyApp({
    super.key,
    required this.authCubit,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: locale,
      builder: (context, child) {
        return MaterialApp.router(
          title: locale.appName,
          locale: locale.locale,
          supportedLocales: AppLocale.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          routerConfig: createAppRouter(authCubit),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
