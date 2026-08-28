import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/widgets/app_button.dart';
import 'package:spicy/core/widgets/price_label.dart';
import 'package:spicy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_state.dart';
import 'package:spicy/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:spicy/features/cart/presentation/cubit/cart_state.dart';
import 'package:spicy/features/order_tracking/presentation/cubit/order_tracking_cubit.dart';
import 'package:spicy/features/order_tracking/presentation/cubit/order_tracking_state.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _notesController = TextEditingController();
  bool _scheduledPickup = false;
  DateTime? _pickupAt;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    final branchState = context.watch<BranchCubit>().state;
    final selectedBranch = branchState is BranchLoaded
        ? branchState.selectedBranch
        : null;
    final customer = context.watch<AuthCubit>().state.user;

    return BlocListener<OrderTrackingCubit, OrderTrackingState>(
      listener: (context, state) {
        if (state is OrderPlaced) {
          context.read<CartCubit>().clearCart();
          context.go('/tracking/${state.order.id}');
        }
        if (state is OrderTrackingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            locale.checkoutTitle,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.surface,
          elevation: 0,
        ),
        body: BlocBuilder<CartCubit, CartState>(
          builder: (context, cartState) {
            if (cartState is! CartUpdated || cartState.items.isEmpty) {
              return Center(child: Text(locale.emptyCart));
            }
            if (selectedBranch == null) {
              return Center(child: Text(locale.chooseBranchFirst));
            }
            if (customer.name.trim().isEmpty || customer.phone.trim().isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    locale.accountContactRequired,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(locale.pickupOrder),
                  _pickupCard(selectedBranch.name, selectedBranch.address),
                  const SizedBox(height: 24),
                  _sectionTitle(locale.pickupTime),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(locale.schedulePickup),
                    subtitle: Text(
                      _scheduledPickup
                          ? _formatPickupAt(_pickupAt)
                          : locale.asSoonAsReady,
                    ),
                    value: _scheduledPickup,
                    onChanged: (value) => setState(() {
                      _scheduledPickup = value;
                      if (!value) _pickupAt = null;
                    }),
                  ),
                  if (_scheduledPickup)
                    OutlinedButton.icon(
                      onPressed: _choosePickupTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        _pickupAt == null
                            ? locale.chooseTime
                            : _formatPickupAt(_pickupAt),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _sectionTitle(locale.contactDetails),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(customer.name),
                    subtitle: Text(customer.phone),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(locale.payment),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(locale.cashAtPickup),
                    subtitle: Text(locale.onlinePaymentLater),
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle(locale.orderComment),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: locale.orderCommentHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle(locale.yourOrder),
                  const SizedBox(height: 12),
                  ...cartState.items.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item.quantity} × ${item.menuItem.name}'),
                      subtitle: Text(
                        locale.translateOrderVariant(item.variant.name),
                      ),
                      trailing: PriceLabel(price: item.totalPrice),
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionTitle(locale.total),
                      PriceLabel(
                        price: cartState.totalPrice,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  BlocBuilder<OrderTrackingCubit, OrderTrackingState>(
                    builder: (context, orderState) {
                      final canPlace = !_scheduledPickup || _pickupAt != null;
                      return AppButton(
                        label: locale.placeOrder,
                        icon: Icons.check_circle_outline_rounded,
                        isLoading: orderState is OrderTrackingLoading,
                        onPressed: canPlace
                            ? () => context
                                  .read<OrderTrackingCubit>()
                                  .placePickupCashOrder(
                                    branchId: selectedBranch.id,
                                    items: cartState.items,
                                    contactName: customer.name,
                                    contactPhone: customer.phone,
                                    pickupAt: _pickupAt,
                                    notes: _notesController.text,
                                  )
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String value) {
    return Text(
      value,
      style: GoogleFonts.playfairDisplay(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.onBackground,
      ),
    );
  }

  Widget _pickupCard(String name, String address) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.storefront_outlined, color: AppTheme.primary),
        title: Text(name),
        subtitle: Text(address),
      ),
    );
  }

  Future<void> _choosePickupTime() async {
    final now = DateTime.now();
    final initial = _pickupAt ?? now.add(const Duration(minutes: 30));
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 14)),
    );
    if (day == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final selected = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    if (!selected.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<AppLocale>().chooseFutureTime)),
      );
      return;
    }
    setState(() => _pickupAt = selected);
  }

  String _formatPickupAt(DateTime? value) {
    if (value == null) return context.read<AppLocale>().chooseTime;
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}
