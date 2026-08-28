import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/widgets/filter_chip_bar.dart';
import 'package:spicy/core/widgets/checkout_bar.dart';
import 'package:spicy/features/branch/domain/entities/branch.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_state.dart';
import 'package:spicy/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:spicy/features/cart/presentation/cubit/cart_state.dart';
import 'package:spicy/features/menu/presentation/cubit/menu_cubit.dart';
import 'package:spicy/features/menu/presentation/cubit/menu_state.dart';
import 'package:spicy/features/menu/presentation/widgets/menu_item_card.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late final ScrollController _scrollController;
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    final branchCubit = context.read<BranchCubit>();
    final state = branchCubit.state;
    if (state is BranchInitial || state is BranchError) {
      branchCubit.loadBranches();
    } else if (state is BranchLoaded && state.selectedBranch != null) {
      context.read<MenuCubit>().loadMenu(state.selectedBranch!.id);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset > 500;
    if (shouldShow != _showBackToTop && mounted) {
      setState(() => _showBackToTop = shouldShow);
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, branchState) {
        if (branchState is BranchInitial || branchState is BranchLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }

        if (branchState is BranchError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppTheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(branchState.message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          context.read<BranchCubit>().loadBranches(),
                      child: Text(locale.retry),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final loadedBranches = branchState as BranchLoaded;
        final selectedBranch = loadedBranches.selectedBranch;
        if (selectedBranch == null) {
          return _BranchPicker(
            branches: loadedBranches.branches,
            onSelected: _selectBranch,
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // App bar
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: true,
                    pinned: true,
                    backgroundColor: AppTheme.surface,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                      title: Text(
                        'SPICY',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onBackground,
                        ),
                      ),
                    ),
                    actions: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.language_rounded),
                        tooltip: locale.language,
                        initialValue: locale.languageCode,
                        onSelected: _changeLanguage,
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'ru', child: Text('Русский')),
                          PopupMenuItem(value: 'en', child: Text('English')),
                          PopupMenuItem(value: 'ar', child: Text('العربية')),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.storefront_outlined),
                        tooltip: locale.changeBranch,
                        onPressed: () =>
                            _showBranchPicker(context, loadedBranches.branches),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search_rounded),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),

                  // Greeting
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedBranch.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onBackground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedBranch.address,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppTheme.secondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // The main category row and optional sandwich row remain
                  // available while products scroll beneath them.
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _MenuFilterHeaderDelegate(
                      height: 100,
                      child: BlocBuilder<MenuCubit, MenuState>(
                        builder: (context, state) {
                          final menuState = state is MenuLoaded ? state : null;
                          if (menuState == null) {
                            return const SizedBox.expand();
                          }

                          final hasSandwichFilters =
                              menuState.sandwichTypes.isNotEmpty &&
                              menuState.selectedSandwichType != null;
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FilterChipBar(
                                categories: menuState.categories,
                                selectedCategory: menuState.selectedCategory,
                                onSelected: context
                                    .read<MenuCubit>()
                                    .filterByCategory,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: hasSandwichFilters
                                    ? FilterChipBar(
                                        categories: menuState.sandwichTypes,
                                        selectedCategory:
                                            menuState.selectedSandwichType!,
                                        labelBuilder: locale.sandwichType,
                                        onSelected: context
                                            .read<MenuCubit>()
                                            .filterBySandwichType,
                                      )
                                    : const SizedBox.expand(),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // Menu grid
                  BlocBuilder<MenuCubit, MenuState>(
                    builder: (context, state) {
                      if (state is MenuLoading) {
                        return const SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                          ),
                        );
                      }
                      if (state is MenuError) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: AppTheme.error,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  locale.somethingWentWrong,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      if (state is MenuLoaded) {
                        return SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop =
                                constraints.crossAxisExtent >= 700;
                            return SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              sliver: SliverGrid(
                                gridDelegate: isDesktop
                                    ? const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 420,
                                        childAspectRatio: 0.85,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      )
                                    : const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 0.65,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final item = state.items[index];
                                  return MenuItemCard(
                                    item: item,
                                    onTap: () =>
                                        context.push('/product/${item.id}'),
                                  );
                                }, childCount: state.items.length),
                              ),
                            );
                          },
                        );
                      }
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    },
                  ),

                  // Bottom padding for checkout bar
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),

              // Checkout bar
              BlocBuilder<CartCubit, CartState>(
                builder: (context, state) {
                  if (state is CartUpdated && state.itemCount > 0) {
                    return CheckoutBar(
                      itemCount: state.itemCount,
                      totalPrice: state.totalPrice,
                      onCheckout: () => context.push('/cart'),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              BlocBuilder<CartCubit, CartState>(
                builder: (context, state) {
                  final hasCart = state is CartUpdated && state.itemCount > 0;
                  return PositionedDirectional(
                    end: 16,
                    bottom: hasCart
                        ? MediaQuery.paddingOf(context).bottom + 94
                        : 16,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: _showBackToTop
                          ? FloatingActionButton.small(
                              key: const ValueKey('menu-back-to-top'),
                              heroTag: 'menu-back-to-top',
                              tooltip: locale.backToTop,
                              onPressed: _scrollToTop,
                              backgroundColor: AppTheme.onBackground,
                              foregroundColor: AppTheme.surface,
                              child: const Icon(
                                Icons.keyboard_arrow_up_rounded,
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('menu-back-to-top-hidden'),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeLanguage(String languageCode) async {
    try {
      await context.read<AppLocale>().selectLanguage(languageCode);
      if (!mounted) return;
      final branchState = context.read<BranchCubit>().state;
      if (branchState is BranchLoaded && branchState.selectedBranch != null) {
        await context.read<MenuCubit>().loadMenu(
          branchState.selectedBranch!.id,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AppLocale>().saveLanguageFailed(error)),
        ),
      );
    }
  }

  void _selectBranch(Branch branch) {
    final currentState = context.read<BranchCubit>().state;
    final previousBranch = currentState is BranchLoaded
        ? currentState.selectedBranch
        : null;
    if (previousBranch != null && previousBranch.id != branch.id) {
      context.read<CartCubit>().clearCart();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AppLocale>().cartClearedForBranch),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
    context.read<BranchCubit>().selectBranch(branch);
    context.read<MenuCubit>().loadMenu(branch.id);
  }

  Future<void> _showBranchPicker(BuildContext context, List<Branch> branches) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(context.read<AppLocale>().selectBranch)),
            ...branches.map(
              (branch) => ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(branch.name),
                subtitle: Text(branch.address),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _selectBranch(branch);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _MenuFilterHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: Material(
        color: AppTheme.surface,
        elevation: overlapsContent ? 2 : 0,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MenuFilterHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}

class _BranchPicker extends StatelessWidget {
  final List<Branch> branches;
  final ValueChanged<Branch> onSelected;

  const _BranchPicker({required this.branches, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return Scaffold(
      appBar: AppBar(title: const Text('SPICY')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locale.selectBranch,
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              locale.selectBranchLater,
              style: GoogleFonts.inter(color: AppTheme.secondary),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: branches.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final branch = branches[index];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const Icon(
                        Icons.storefront,
                        color: AppTheme.primary,
                      ),
                      title: Text(branch.name),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(branch.address),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onSelected(branch),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
