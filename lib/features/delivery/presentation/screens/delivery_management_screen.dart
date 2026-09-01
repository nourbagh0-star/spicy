import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/widgets/price_label.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The same operational page is used by a manager for their branch and by the
/// owner for every branch. Driver records stay owner-only by design.
class DeliveryManagementScreen extends StatefulWidget {
  final bool isOwner;

  const DeliveryManagementScreen({super.key, required this.isOwner});

  @override
  State<DeliveryManagementScreen> createState() =>
      _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen> {
  late Future<_DeliveryData> _data = _load();
  String? _selectedBranchId;

  Future<_DeliveryData> _load() async {
    final db = Supabase.instance.client;
    List<Map<String, dynamic>> branches;
    if (widget.isOwner) {
      branches = List<Map<String, dynamic>>.from(
        await db.from('branches').select('id,name,address').order('name'),
      );
    } else {
      final profile = await db
          .from('profiles')
          .select('assigned_branch_id')
          .eq('id', db.auth.currentUser!.id)
          .single();
      final branchId = profile['assigned_branch_id'] as String?;
      if (branchId == null) {
        throw StateError('Вам ещё не назначили филиал.');
      }
      branches = List<Map<String, dynamic>>.from(
        await db.from('branches').select('id,name,address').eq('id', branchId),
      );
    }
    if (branches.isEmpty) throw StateError('Нет доступных филиалов.');
    final branchId = _selectedBranchId ?? branches.first['id'] as String;
    final settings = await db
        .from('branch_delivery_settings')
        .select()
        .eq('branch_id', branchId)
        .maybeSingle();
    final tiers = List<Map<String, dynamic>>.from(
      await db
          .from('branch_delivery_fee_tiers')
          .select()
          .eq('branch_id', branchId)
          .order('from_distance_meters'),
    );
    final drivers = widget.isOwner
        ? List<Map<String, dynamic>>.from(
            await db
                .from('branch_drivers')
                .select()
                .eq('branch_id', branchId)
                .order('full_name'),
          )
        : const <Map<String, dynamic>>[];
    return _DeliveryData(
      branches: branches,
      selectedBranchId: branchId,
      settings: settings == null ? null : Map<String, dynamic>.from(settings),
      tiers: tiers,
      drivers: drivers,
    );
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<void> _saveSettings(_DeliveryData data) async {
    final locale = context.read<AppLocale>();
    final radius = TextEditingController(
      text: (((data.settings?['maximum_distance_meters'] as int?) ?? 0) / 1000)
          .toStringAsFixed(1),
    );
    var enabled = data.settings?['is_enabled'] as bool? ?? false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            locale.text(
              ru: 'Настройки доставки',
              en: 'Delivery settings',
              ar: 'إعدادات التوصيل',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  locale.text(
                    ru: 'Доставка доступна',
                    en: 'Delivery available',
                    ar: 'التوصيل متاح',
                  ),
                ),
                value: enabled,
                onChanged: (value) => setDialogState(() => enabled = value),
              ),
              TextField(
                controller: radius,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: locale.text(
                    ru: 'Максимальная дистанция, км',
                    en: 'Maximum distance, km',
                    ar: 'أقصى مسافة، كم',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                locale.text(
                  ru: 'Минимальный заказ: 150 ₽. Добавьте тариф хотя бы для первой зоны перед включением доставки.',
                  en: 'Minimum order: 150 ₽. Add a fee tier before enabling delivery.',
                  ar: 'الحد الأدنى: 150 ₽. أضف شريحة رسوم قبل تشغيل التوصيل.',
                ),
                style: TextStyle(fontSize: 12, color: AppTheme.secondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(locale.text(ru: 'Отмена', en: 'Cancel', ar: 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(locale.text(ru: 'Сохранить', en: 'Save', ar: 'حفظ')),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final parsed = double.tryParse(radius.text.replaceAll(',', '.'));
    final meters = ((parsed ?? 0) * 1000).round();
    if (meters < 1 || meters > 100000) {
      _message(
        locale.text(
          ru: 'Укажите дистанцию от 0,1 до 100 км.',
          en: 'Enter a distance from 0.1 to 100 km.',
          ar: 'أدخل مسافة من 0.1 إلى 100 كم.',
        ),
      );
      return;
    }
    await Supabase.instance.client.from('branch_delivery_settings').upsert({
      'branch_id': data.selectedBranchId,
      'is_enabled': enabled,
      'maximum_distance_meters': meters,
      'minimum_order_kopeks': 15000,
    });
    _reload();
  }

  Future<void> _editTier(
    _DeliveryData data, [
    Map<String, dynamic>? tier,
  ]) async {
    final locale = context.read<AppLocale>();
    final from = TextEditingController(
      text: tier == null
          ? '0'
          : '${(tier['from_distance_meters'] as int) / 1000}',
    );
    final to = TextEditingController(
      text: tier == null
          ? '3'
          : '${(tier['to_distance_meters'] as int) / 1000}',
    );
    final fee = TextEditingController(
      text: tier == null ? '0' : '${(tier['fee_kopeks'] as int) / 100}',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tier == null
              ? locale.text(
                  ru: 'Новый тариф',
                  en: 'New fee tier',
                  ar: 'شريحة رسوم جديدة',
                )
              : locale.text(
                  ru: 'Изменить тариф',
                  en: 'Edit fee tier',
                  ar: 'تعديل شريحة الرسوم',
                ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _numberField(
              from,
              locale.text(ru: 'От, км', en: 'From, km', ar: 'من، كم'),
            ),
            _numberField(
              to,
              locale.text(ru: 'До, км', en: 'To, km', ar: 'إلى، كم'),
            ),
            _numberField(
              fee,
              locale.text(ru: 'Стоимость, ₽', en: 'Fee, ₽', ar: 'الرسوم، ₽'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(locale.text(ru: 'Отмена', en: 'Cancel', ar: 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(locale.text(ru: 'Сохранить', en: 'Save', ar: 'حفظ')),
          ),
        ],
      ),
    );
    if (save != true) return;
    int meters(TextEditingController controller) =>
        ((double.tryParse(controller.text.replaceAll(',', '.')) ?? -1) * 1000)
            .round();
    final start = meters(from);
    final end = meters(to);
    final rubles = double.tryParse(fee.text.replaceAll(',', '.'));
    if (start < 0 || end <= start || rubles == null || rubles < 0) {
      _message(
        locale.text(
          ru: 'Проверьте границы зоны и стоимость.',
          en: 'Check the zone limits and fee.',
          ar: 'تحقق من حدود المنطقة والرسوم.',
        ),
      );
      return;
    }
    final values = {
      'branch_id': data.selectedBranchId,
      'from_distance_meters': start,
      'to_distance_meters': end,
      'fee_kopeks': (rubles * 100).round(),
    };
    if (tier == null) {
      await Supabase.instance.client
          .from('branch_delivery_fee_tiers')
          .insert(values);
    } else {
      await Supabase.instance.client
          .from('branch_delivery_fee_tiers')
          .update(values)
          .eq('id', tier['id']);
    }
    _reload();
  }

  Future<void> _deleteTier(String id) async {
    await Supabase.instance.client
        .from('branch_delivery_fee_tiers')
        .delete()
        .eq('id', id);
    _reload();
  }

  Future<void> _editDriver(
    _DeliveryData data, [
    Map<String, dynamic>? driver,
  ]) async {
    final locale = context.read<AppLocale>();
    final name = TextEditingController(
      text: driver?['full_name'] as String? ?? '',
    );
    final phone = TextEditingController(
      text: driver?['phone'] as String? ?? '',
    );
    var active = driver?['is_active'] as bool? ?? true;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            driver == null
                ? locale.text(
                    ru: 'Новый водитель',
                    en: 'New driver',
                    ar: 'سائق جديد',
                  )
                : locale.text(ru: 'Водитель', en: 'Driver', ar: 'السائق'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: locale.text(
                    ru: 'Имя водителя',
                    en: 'Driver name',
                    ar: 'اسم السائق',
                  ),
                ),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: locale.phone),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  locale.text(ru: 'Активен', en: 'Active', ar: 'نشط'),
                ),
                value: active,
                onChanged: (value) => setDialogState(() => active = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(locale.text(ru: 'Отмена', en: 'Cancel', ar: 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(locale.text(ru: 'Сохранить', en: 'Save', ar: 'حفظ')),
            ),
          ],
        ),
      ),
    );
    if (save != true || name.text.trim().length < 2) return;
    final values = {
      'branch_id': data.selectedBranchId,
      'full_name': name.text.trim(),
      'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
      'is_active': active,
    };
    if (driver == null) {
      await Supabase.instance.client.from('branch_drivers').insert(values);
    } else {
      await Supabase.instance.client
          .from('branch_drivers')
          .update(values)
          .eq('id', driver['id']);
    }
    _reload();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Widget _numberField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      );

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(widget.isOwner ? '/owner' : '/manager'),
        ),
        title: Text(
          locale.text(ru: 'Доставка', en: 'Delivery', ar: 'التوصيل'),
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FutureBuilder<_DeliveryData>(
        future: _data,
        builder: (context, snapshot) => snapshot.hasData
            ? FloatingActionButton.extended(
                onPressed: () => _editTier(snapshot.data!),
                icon: const Icon(Icons.add),
                label: Text(
                  locale.text(ru: 'Тариф', en: 'Fee tier', ar: 'شريحة رسوم'),
                ),
              )
            : const SizedBox.shrink(),
      ),
      body: FutureBuilder<_DeliveryData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString().replaceFirst('Bad state: ', ''),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final data = snapshot.data!;
          final settings = data.settings;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.isOwner)
                DropdownButtonFormField<String>(
                  initialValue: data.selectedBranchId,
                  decoration: InputDecoration(
                    labelText: locale.text(
                      ru: 'Филиал',
                      en: 'Branch',
                      ar: 'الفرع',
                    ),
                  ),
                  items: data.branches
                      .map(
                        (branch) => DropdownMenuItem(
                          value: branch['id'] as String,
                          child: Text(branch['name'] as String),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedBranchId = value;
                        _data = _load();
                      });
                    }
                  },
                )
              else
                Text(
                  data.branches.first['name'] as String,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  leading: Icon(
                    settings?['is_enabled'] == true
                        ? Icons.delivery_dining
                        : Icons.delivery_dining_outlined,
                    color: AppTheme.primary,
                  ),
                  title: Text(
                    settings?['is_enabled'] == true
                        ? locale.text(
                            ru: 'Доставка включена',
                            en: 'Delivery is enabled',
                            ar: 'التوصيل مفعّل',
                          )
                        : locale.text(
                            ru: 'Доставка выключена',
                            en: 'Delivery is off',
                            ar: 'التوصيل متوقف',
                          ),
                  ),
                  subtitle: Text(
                    locale.text(
                      ru: 'До ${((settings?['maximum_distance_meters'] as int? ?? 0) / 1000).toStringAsFixed(1)} км · минимум 150 ₽',
                      en: 'Up to ${((settings?['maximum_distance_meters'] as int? ?? 0) / 1000).toStringAsFixed(1)} km · minimum 150 ₽',
                      ar: 'حتى ${((settings?['maximum_distance_meters'] as int? ?? 0) / 1000).toStringAsFixed(1)} كم · الحد الأدنى 150 ₽',
                    ),
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _saveSettings(data),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                locale.text(
                  ru: 'Тарифы по расстоянию',
                  en: 'Distance fee tiers',
                  ar: 'رسوم حسب المسافة',
                ),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (data.tiers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    locale.text(
                      ru: 'Тарифов пока нет. Добавьте первый тариф кнопкой внизу.',
                      en: 'No fee tiers yet. Add the first one with the button below.',
                      ar: 'لا توجد شرائح رسوم بعد. أضف الأولى بالزر أدناه.',
                    ),
                  ),
                )
              else
                ...data.tiers.map(
                  (tier) => Card(
                    child: ListTile(
                      title: Text(
                        '${((tier['from_distance_meters'] as int) / 1000).toStringAsFixed(1)} – ${((tier['to_distance_meters'] as int) / 1000).toStringAsFixed(1)} км',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PriceLabel(price: (tier['fee_kopeks'] as int) / 100),
                          IconButton(
                            onPressed: () => _deleteTier(tier['id'] as String),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _editTier(data, tier),
                    ),
                  ),
                ),
              if (widget.isOwner) ...[
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        locale.text(
                          ru: 'Водители филиала',
                          en: 'Branch drivers',
                          ar: 'سائقو الفرع',
                        ),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editDriver(data),
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                if (data.drivers.isEmpty)
                  Text(
                    locale.text(
                      ru: 'Добавьте водителя, чтобы менеджер мог назначить его на доставку.',
                      en: 'Add a driver so a manager can assign deliveries.',
                      ar: 'أضف سائقاً ليتمكن المدير من تعيينه للتوصيل.',
                    ),
                  )
                else
                  ...data.drivers.map(
                    (driver) => Card(
                      child: ListTile(
                        leading: Icon(
                          driver['is_active'] == true
                              ? Icons.person
                              : Icons.person_off_outlined,
                          color: AppTheme.primary,
                        ),
                        title: Text(driver['full_name'] as String),
                        subtitle: Text(driver['phone'] as String? ?? ''),
                        trailing: IconButton(
                          onPressed: () async {
                            await Supabase.instance.client
                                .from('branch_drivers')
                                .delete()
                                .eq('id', driver['id']);
                            _reload();
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppTheme.primary,
                          ),
                        ),
                        onTap: () => _editDriver(data, driver),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 88),
            ],
          );
        },
      ),
    );
  }
}

class _DeliveryData {
  final List<Map<String, dynamic>> branches;
  final String selectedBranchId;
  final Map<String, dynamic>? settings;
  final List<Map<String, dynamic>> tiers;
  final List<Map<String, dynamic>> drivers;
  const _DeliveryData({
    required this.branches,
    required this.selectedBranchId,
    required this.settings,
    required this.tiers,
    required this.drivers,
  });
}
