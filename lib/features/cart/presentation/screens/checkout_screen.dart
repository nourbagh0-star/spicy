import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/widgets/app_button.dart';
import 'package:spicy/core/widgets/app_error_snackbar.dart';
import 'package:spicy/core/widgets/price_label.dart';
import 'package:spicy/core/widgets/responsive_content.dart';
import 'package:spicy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_state.dart';
import 'package:spicy/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:spicy/features/cart/presentation/cubit/cart_state.dart';
import 'package:spicy/features/cart/domain/entities/cart_item.dart';
import 'package:spicy/features/order_tracking/presentation/cubit/order_tracking_cubit.dart';
import 'package:spicy/features/order_tracking/presentation/cubit/order_tracking_state.dart';
import 'package:spicy/features/order_tracking/domain/entities/delivery_quote.dart';
import 'package:spicy/features/profile/domain/entities/saved_address.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _notesController = TextEditingController();
  bool _scheduledPickup = false;
  DateTime? _pickupAt;
  bool _isDelivery = false;
  late Future<List<SavedAddress>> _addresses;
  SavedAddress? _selectedAddress;
  DeliveryQuote? _deliveryQuote;
  bool _loadingQuote = false;

  @override
  void initState() {
    super.initState();
    _addresses = _loadAddresses();
  }

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
          AppErrorSnackBar.show(context, state.message);
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
              child: ResponsiveContent(
                maxWidth: 760,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(
                      locale.text(
                        ru: 'Способ получения',
                        en: 'Order type',
                        ar: 'طريقة الاستلام',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          icon: const Icon(Icons.storefront_outlined),
                          label: Text(locale.pickupOrder),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: const Icon(Icons.delivery_dining_outlined),
                          label: Text(locale.delivery),
                        ),
                      ],
                      selected: {_isDelivery},
                      onSelectionChanged: (value) {
                        final delivery = value.first;
                        setState(() {
                          _isDelivery = delivery;
                          _deliveryQuote = null;
                        });
                        if (delivery) _refreshQuote(cartState.items);
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!_isDelivery)
                      _pickupCard(selectedBranch.name, selectedBranch.address)
                    else
                      _deliveryAddressSection(locale, cartState.items),
                    const SizedBox(height: 24),
                    _sectionTitle(
                      _isDelivery
                          ? locale.text(
                              ru: 'Время доставки',
                              en: 'Delivery time',
                              ar: 'وقت التوصيل',
                            )
                          : locale.pickupTime,
                    ),
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
                        onPressed: () =>
                            _choosePickupTime(onlyToday: _isDelivery),
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
                      title: Text(
                        _isDelivery
                            ? locale.text(
                                ru: 'Наличными при доставке',
                                en: 'Cash on delivery',
                                ar: 'الدفع نقداً عند التوصيل',
                              )
                            : locale.cashAtPickup,
                      ),
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
                    if (_isDelivery && _deliveryQuote != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(locale.delivery),
                          PriceLabel(price: _deliveryQuote!.deliveryFeeRubles),
                        ],
                      ),
                    if (_isDelivery && _deliveryQuote != null) const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionTitle(locale.total),
                        PriceLabel(
                          price:
                              cartState.totalPrice +
                              (_deliveryQuote?.deliveryFeeRubles ?? 0),
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
                        final canPlace =
                            (!_scheduledPickup || _pickupAt != null) &&
                            (!_isDelivery ||
                                (_selectedAddress != null &&
                                    _deliveryQuote != null &&
                                    cartState.totalPrice >=
                                        _deliveryQuote!.minimumOrderRubles));
                        return AppButton(
                          label: locale.placeOrder,
                          icon: Icons.check_circle_outline_rounded,
                          isLoading: orderState is OrderTrackingLoading,
                          onPressed: canPlace
                              ? () {
                                  final cubit = context
                                      .read<OrderTrackingCubit>();
                                  if (_isDelivery) {
                                    final address = _selectedAddress!;
                                    cubit.placeDeliveryCashOrder(
                                      items: cartState.items,
                                      contactName: customer.name,
                                      contactPhone: customer.phone,
                                      deliveryAddress: [
                                        address.addressLine,
                                        if (address.details.isNotEmpty)
                                          address.details,
                                      ].join(', '),
                                      latitude: address.latitude!,
                                      longitude: address.longitude!,
                                      deliveryScheduledAt: _pickupAt,
                                      notes: _notesController.text,
                                    );
                                  } else {
                                    cubit.placePickupCashOrder(
                                      branchId: selectedBranch.id,
                                      items: cartState.items,
                                      contactName: customer.name,
                                      contactPhone: customer.phone,
                                      pickupAt: _pickupAt,
                                      notes: _notesController.text,
                                    );
                                  }
                                }
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
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

  Widget _deliveryAddressSection(AppLocale locale, List<CartItem> items) {
    return FutureBuilder<List<SavedAddress>>(
      future: _addresses,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final addresses = snapshot.data ?? const <SavedAddress>[];
        final withPin = addresses
            .where((address) => address.hasMapLocation)
            .toList(growable: false);
        if (withPin.isEmpty) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.location_off_outlined),
              title: Text(
                locale.text(
                  ru: 'Нет адреса с точкой на карте',
                  en: 'No address has a map pin',
                  ar: 'لا يوجد عنوان مع نقطة على الخريطة',
                ),
              ),
              subtitle: Text(
                locale.text(
                  ru: 'Добавьте адрес и отметьте точку в профиле.',
                  en: 'Add an address and a map pin in Profile.',
                  ar: 'أضف عنواناً ونقطة على الخريطة في الملف الشخصي.',
                ),
              ),
              trailing: TextButton(
                onPressed: () => context.go('/profile'),
                child: Text(locale.profile),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<SavedAddress>(
              initialValue: _selectedAddress,
              decoration: InputDecoration(
                labelText: locale.deliveryAddress,
                border: const OutlineInputBorder(),
              ),
              items: withPin
                  .map(
                    (address) => DropdownMenuItem(
                      value: address,
                      child: Text('${address.label} — ${address.addressLine}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (address) {
                setState(() => _selectedAddress = address);
                _refreshQuote(items);
              },
            ),
            const SizedBox(height: 10),
            if (_loadingQuote)
              const LinearProgressIndicator(color: AppTheme.primary)
            else if (_selectedAddress != null && _deliveryQuote == null)
              Text(
                locale.text(
                  ru: 'Ни один филиал сейчас не может доставить этот заказ по выбранному адресу.',
                  en: 'No branch can deliver this order to the selected address right now.',
                  ar: 'لا يمكن لأي فرع توصيل هذا الطلب إلى العنوان المحدد الآن.',
                ),
                style: const TextStyle(color: AppTheme.error),
              )
            else if (_deliveryQuote != null)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.storefront_outlined,
                    color: AppTheme.primary,
                  ),
                  title: Text(_deliveryQuote!.branchName),
                  subtitle: Text(
                    '${_deliveryQuote!.branchAddress}\n${_deliveryQuote!.distanceLabel}',
                  ),
                  trailing: PriceLabel(
                    price: _deliveryQuote!.deliveryFeeRubles,
                  ),
                ),
              ),
            if (_deliveryQuote != null &&
                context.read<CartCubit>().state is CartUpdated &&
                (context.read<CartCubit>().state as CartUpdated).totalPrice <
                    _deliveryQuote!.minimumOrderRubles)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  locale.text(
                    ru: 'Минимальный заказ для доставки: ${_deliveryQuote!.minimumOrderRubles.toStringAsFixed(0)} ₽',
                    en: 'Minimum delivery order: ${_deliveryQuote!.minimumOrderRubles.toStringAsFixed(0)} ₽',
                    ar: 'الحد الأدنى للتوصيل: ${_deliveryQuote!.minimumOrderRubles.toStringAsFixed(0)} ₽',
                  ),
                  style: const TextStyle(color: AppTheme.error),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<List<SavedAddress>> _loadAddresses() async {
    final rows = await Supabase.instance.client
        .from('customer_addresses')
        .select()
        .order('is_default', ascending: false)
        .order('created_at');
    return (rows as List<dynamic>)
        .map(
          (row) => _savedAddressFromRow(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  SavedAddress _savedAddressFromRow(Map<String, dynamic> row) => SavedAddress(
    id: row['id'] as String,
    label: row['label'] as String,
    addressLine: row['address_line'] as String,
    apartment: row['apartment'] as String? ?? '',
    entrance: row['entrance'] as String? ?? '',
    floor: row['floor'] as String? ?? '',
    notes: row['notes'] as String? ?? '',
    latitude: (row['latitude'] as num?)?.toDouble(),
    longitude: (row['longitude'] as num?)?.toDouble(),
    isDefault: row['is_default'] as bool? ?? false,
  );

  Future<void> _refreshQuote(List<CartItem> items) async {
    final address = _selectedAddress;
    if (address == null || !address.hasMapLocation) return;
    setState(() {
      _loadingQuote = true;
      _deliveryQuote = null;
    });
    try {
      final quote = await context.read<OrderTrackingCubit>().getDeliveryQuote(
        latitude: address.latitude!,
        longitude: address.longitude!,
        items: items,
      );
      if (mounted) setState(() => _deliveryQuote = quote);
    } catch (_) {
      if (mounted) setState(() => _deliveryQuote = null);
    } finally {
      if (mounted) setState(() => _loadingQuote = false);
    }
  }

  Future<void> _choosePickupTime({required bool onlyToday}) async {
    final now = DateTime.now();
    final initial = _pickupAt ?? now.add(const Duration(minutes: 30));
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: onlyToday
          ? DateTime(now.year, now.month, now.day)
          : now.add(const Duration(days: 14)),
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
