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

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final AppLocale _locale;
  late final OrderTrackingCubit _orderTrackingCubit;

  @override
  void initState() {
    super.initState();
    _locale = context.read<AppLocale>();
    _orderTrackingCubit = context.read<OrderTrackingCubit>();
    _locale.addListener(_reloadForLanguageChange);
    _orderTrackingCubit.loadOrders();
  }

  @override
  void dispose() {
    _locale.removeListener(_reloadForLanguageChange);
    super.dispose();
  }

  void _reloadForLanguageChange() {
    if (!mounted) return;
    _orderTrackingCubit.loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          locale.myOrders,
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: BlocBuilder<OrderTrackingCubit, OrderTrackingState>(
        builder: (context, state) {
          if (state is OrderTrackingLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          if (state is OrdersLoaded) {
            if (state.orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: AppTheme.outline.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      locale.noOrders,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onBackground,
                      ),
                    ),
                  ],
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1050;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        isWide ? 28 : 16,
                        20,
                        isWide ? 28 : 16,
                        96,
                      ),
                      itemCount: state.orders.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isWide ? 2 : 1,
                        mainAxisExtent: 220,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                      ),
                      itemBuilder: (context, index) {
                        final order = state.orders[index];
                        return _OrderCard(
                          order: order,
                          onTap: () => context.push('/tracking/${order.id}'),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    final visibleItems = order.items.take(2).toList(growable: false);
    final hiddenItemCount = order.items.length - visibleItems.length;
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: Color(0x1A6B6661)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    locale.orderNumber(
                      order.orderNumber ?? order.id.substring(0, 8),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        order.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    ),
                    child: Text(
                      locale.orderStatus(order.status.name),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(order.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _orderMeta(order),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.secondary,
                ),
              ),
              const Divider(height: 24),
              ...visibleItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${item.quantity} × ${item.menuItem.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.secondary,
                    ),
                  ),
                ),
              ),
              if (hiddenItemCount > 0)
                Text(
                  locale.moreItems(hiddenItemCount),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  PriceLabel(
                    price: order.totalPrice,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    order.isActive ? locale.trackOrder : locale.details,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _orderMeta(Order order) {
    final local = order.createdAt.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final branch = order.branchName.trim();
    return branch.isEmpty ? '$date · $time' : '$date · $time · $branch';
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return const Color(0xFF2E7D32);
      case OrderStatus.cancelled:
        return AppTheme.error;
      case OrderStatus.onTheWay:
        return const Color(0xFF1565C0);
      default:
        return AppTheme.primary;
    }
  }
}
