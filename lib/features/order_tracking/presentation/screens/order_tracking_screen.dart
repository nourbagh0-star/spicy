import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/widgets/price_label.dart';
import 'package:spicy/features/order_tracking/domain/entities/order.dart';
import 'package:spicy/features/order_tracking/presentation/cubit/order_tracking_cubit.dart';
import 'package:spicy/features/order_tracking/presentation/cubit/order_tracking_state.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_state.dart';
import 'package:spicy/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:spicy/features/menu/presentation/cubit/menu_cubit.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_variant.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_modifier.dart';
import 'package:spicy/features/branch/domain/entities/branch.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late final RealtimeChannel _orderChannel;
  late final AppLocale _locale;
  late final OrderTrackingCubit _orderTrackingCubit;

  @override
  void initState() {
    super.initState();
    _locale = context.read<AppLocale>();
    _orderTrackingCubit = context.read<OrderTrackingCubit>();
    _locale.addListener(_reloadForLanguageChange);
    _orderTrackingCubit.loadOrderDetail(widget.orderId);
    _orderChannel = Supabase.instance.client
        .channel('customer-order-${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (_) {
            if (mounted) {
              _orderTrackingCubit.refreshOrderDetail(widget.orderId);
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _locale.removeListener(_reloadForLanguageChange);
    Supabase.instance.client.removeChannel(_orderChannel);
    super.dispose();
  }

  void _reloadForLanguageChange() {
    if (mounted) {
      _orderTrackingCubit.refreshOrderDetail(widget.orderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return Scaffold(
      appBar: AppBar(title: Text(locale.orderTitle)),
      body: BlocBuilder<OrderTrackingCubit, OrderTrackingState>(
        builder: (context, state) {
          if (state is OrderTrackingLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is OrderTrackingError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(state.message, textAlign: TextAlign.center),
              ),
            );
          }
          final order = state is OrderDetailLoaded
              ? state.order
              : state is OrderPlaced
              ? state.order
              : null;
          if (order == null) return const SizedBox.shrink();
          return _OrderDetails(order: order);
        },
      ),
    );
  }
}

class _OrderDetails extends StatelessWidget {
  final Order order;

  const _OrderDetails({required this.order});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          locale.orderNumber(order.orderNumber ?? order.id.substring(0, 8)),
          style: GoogleFonts.playfairDisplay(
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Chip(
          label: Text(locale.orderStatus(order.status.name)),
          backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.storefront_outlined,
            color: AppTheme.primary,
          ),
          title: Text(order.branchName.isEmpty ? 'Spicy' : order.branchName),
          subtitle: Text(order.deliveryAddress),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_outlined, color: AppTheme.primary),
          title: Text(
            order.estimatedDelivery == null
                ? locale.pickupAsSoonAsReady
                : locale.pickupAt(_formatDate(order.estimatedDelivery!)),
          ),
          subtitle: Text(locale.cashOnPickup),
        ),
        const Divider(height: 32),
        ...order.items.map(
          (item) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${item.quantity} × ${item.menuItem.name}'),
            subtitle: Text(locale.translateOrderVariant(item.variant.name)),
            trailing: PriceLabel(price: item.totalPrice),
          ),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            locale.total,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          trailing: PriceLabel(
            price: order.totalPrice,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (order.status == OrderStatus.delivered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/review/new?orderId=${order.id}&branchId=${order.branchId}',
                ),
                icon: const Icon(Icons.star_outline_rounded),
                label: Text(locale.reviewBranch),
              ),
            ),
          ),
        if (order.status == OrderStatus.delivered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push('/review/items?orderId=${order.id}'),
                icon: const Icon(Icons.restaurant_menu_outlined),
                label: Text(locale.rateItems),
              ),
            ),
          ),
        SizedBox(
          height: 52,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _repeatOrder(context, order),
            icon: const Icon(Icons.replay_outlined),
            label: Text(locale.repeatOrder),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.restaurant_menu_outlined),
            label: Text(locale.returnToMenu),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _repeatOrder(BuildContext context, Order order) async {
    final locale = context.read<AppLocale>();
    if (order.branchId.isEmpty) {
      _showMessage(context, locale.orderBranchMissing);
      return;
    }
    final branchState = context.read<BranchCubit>().state;
    if (branchState is! BranchLoaded) {
      _showMessage(context, locale.chooseBranchFirst);
      return;
    }
    Branch? branch;
    for (final candidate in branchState.branches) {
      if (candidate.id == order.branchId) {
        branch = candidate;
        break;
      }
    }
    if (branch == null) {
      _showMessage(context, locale.branchUnavailable);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.repeatOrderQuestion),
        content: Text(locale.repeatOrderExplanation(order.branchName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(locale.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(locale.continueLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final menuItems = await context.read<MenuCubit>().loadMenu(
        order.branchId,
      );
      if (!context.mounted) return;
      final cart = context.read<CartCubit>();
      final lines = <_RepeatLine>[];
      final skipped = <String>[];
      for (final previous in order.items) {
        MenuItem? item;
        for (final candidate in menuItems) {
          if (candidate.id == previous.menuItem.id) {
            item = candidate;
            break;
          }
        }
        if (item == null) {
          skipped.add(previous.menuItem.name);
          continue;
        }
        MenuItemVariant? variant;
        for (final candidate in item.variants) {
          if (candidate.id == previous.variant.id) {
            variant = candidate;
            break;
          }
        }
        if (variant == null) {
          skipped.add(previous.menuItem.name);
          continue;
        }
        final previousIds = previous.modifiers.map((item) => item.id).toSet();
        final modifiers = item.modifierGroups
            .expand((group) => group.options)
            .where((option) => previousIds.contains(option.id))
            .toList(growable: false);
        final modifiersAreValid = item.modifierGroups.every((group) {
          final selected = modifiers
              .where((option) => group.options.contains(option))
              .length;
          return selected >= group.minimumSelections &&
              selected <= group.maximumSelections;
        });
        if (!modifiersAreValid) {
          skipped.add(previous.menuItem.name);
          continue;
        }
        lines.add(
          _RepeatLine(
            item,
            variant,
            previous.quantity,
            modifiers,
            previous.specialInstructions,
          ),
        );
      }
      if (lines.isEmpty) {
        _showMessage(context, locale.previousOrderUnavailable);
        return;
      }
      context.read<BranchCubit>().selectBranch(branch);
      cart.clearCart();
      for (final line in lines) {
        cart.addToCart(
          line.item,
          line.variant,
          quantity: line.quantity,
          modifiers: line.modifiers,
          specialInstructions: line.specialInstructions,
        );
      }
      if (!context.mounted) return;
      final note = locale.repeatedItems(lines.length, skipped);
      _showMessage(context, note);
      context.go('/cart');
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, locale.repeatOrderFailed);
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RepeatLine {
  final MenuItem item;
  final MenuItemVariant variant;
  final int quantity;
  final List<MenuItemModifierOption> modifiers;
  final String? specialInstructions;

  const _RepeatLine(
    this.item,
    this.variant,
    this.quantity,
    this.modifiers,
    this.specialInstructions,
  );
}
