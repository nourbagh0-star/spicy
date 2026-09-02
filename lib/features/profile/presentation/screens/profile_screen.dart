import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/theme/app_theme_controller.dart';
import 'package:spicy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_state.dart';
import 'package:spicy/features/menu/presentation/cubit/menu_cubit.dart';
import 'package:spicy/features/profile/domain/entities/saved_address.dart';
import 'package:spicy/features/profile/domain/entities/user_profile.dart';
import 'package:spicy/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:spicy/features/profile/presentation/cubit/profile_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileCubit _profileCubit;

  @override
  void initState() {
    super.initState();
    _profileCubit = context.read<ProfileCubit>();
    _profileCubit.loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    final themeController = context.watch<AppThemeController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          locale.profile,
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ProfileError && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_friendlyError(state.message, locale))),
            );
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading || state is ProfileInitial) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          if (state is ProfileError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 44),
                    const SizedBox(height: 12),
                    Text(_friendlyError(state.message, locale)),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _profileCubit.loadProfile,
                      child: Text(locale.retry),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is! ProfileLoaded) return const SizedBox.shrink();
          return _ProfileContent(
            profile: state.profile,
            locale: locale,
            onEditDetails: () => _editDetails(state.profile),
            onAddAddress: () => _editAddress(),
            onEditAddress: _editAddress,
            onDeleteAddress: _deleteAddress,
            onLanguage: () => _showLanguagePicker(locale),
            onTheme: () => _showThemePicker(themeController),
            themeMode: themeController.themeMode,
            onLogout: () => context.read<AuthCubit>().logout(),
            onDeleteAccount: _confirmDeleteAccount,
          );
        },
      ),
    );
  }

  Future<void> _editDetails(UserProfile profile) async {
    final updated = await showModalBottomSheet<_PersonalDetails>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PersonalDetailsSheet(profile: profile),
    );
    if (updated == null) return;
    await _profileCubit.updatePersonalDetails(
      fullName: updated.fullName,
      phone: updated.phone,
    );
  }

  Future<void> _editAddress([SavedAddress? address]) async {
    final locale = context.read<AppLocale>();
    final saved = await showModalBottomSheet<SavedAddress>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddressEditor(address: address),
    );
    if (saved == null) return;
    final didSave = await _profileCubit.saveAddress(saved);
    if (!mounted || !didSave) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _text(locale, 'Адрес сохранён.', 'Address saved.', 'تم حفظ العنوان.'),
        ),
      ),
    );
  }

  Future<void> _deleteAddress(SavedAddress address) async {
    final locale = context.read<AppLocale>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _text(locale, 'Удалить адрес?', 'Delete address?', 'حذف العنوان؟'),
        ),
        content: Text(address.addressLine),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_text(locale, 'Отмена', 'Cancel', 'إلغاء')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _text(locale, 'Удалить', 'Delete', 'حذف'),
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _profileCubit.deleteAddress(address.id);
  }

  Future<void> _showLanguagePicker(AppLocale locale) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<String>(
              groupValue: locale.languageCode,
              onChanged: (value) => Navigator.pop(sheetContext, value),
              child: const Column(
                children: [
                  RadioListTile(value: 'ru', title: Text('Русский')),
                  RadioListTile(value: 'en', title: Text('English')),
                  RadioListTile(value: 'ar', title: Text('العربية')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || selected == locale.languageCode) return;

    try {
      await locale.selectLanguage(selected);
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

  Future<void> _showThemePicker(AppThemeController themeController) async {
    final locale = context.read<AppLocale>();
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: themeController.themeMode,
          onChanged: (value) => Navigator.pop(sheetContext, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile(
                value: ThemeMode.system,
                title: Text(
                  _text(
                    locale,
                    'Как в системе',
                    'Use system setting',
                    'حسب إعدادات الجهاز',
                  ),
                ),
              ),
              RadioListTile(
                value: ThemeMode.light,
                title: Text(_text(locale, 'Светлая', 'Light', 'فاتح')),
              ),
              RadioListTile(
                value: ThemeMode.dark,
                title: Text(_text(locale, 'Тёмная', 'Dark', 'داكن')),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) await themeController.select(selected);
  }

  Future<void> _confirmDeleteAccount() async {
    final locale = context.read<AppLocale>();
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            _text(locale, 'Удалить аккаунт?', 'Delete account?', 'حذف الحساب؟'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(
                  locale,
                  'Ваш профиль и сохранённые адреса будут удалены. Прошлые заказы останутся только как анонимные записи ресторана.',
                  'Your profile and saved addresses will be deleted. Past orders stay only as anonymous restaurant records.',
                  'سيتم حذف ملفك الشخصي والعناوين المحفوظة. ستبقى الطلبات السابقة كسجلات مجهولة للمطعم فقط.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(labelText: 'DELETE'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_text(locale, 'Отмена', 'Cancel', 'إلغاء')),
            ),
            TextButton(
              onPressed: controller.text == 'DELETE'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: Text(
                _text(
                  locale,
                  'Удалить аккаунт',
                  'Delete account',
                  'حذف الحساب',
                ),
                style: const TextStyle(color: AppTheme.error),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (confirmed == true) await _profileCubit.deleteAccount();
  }

  String _friendlyError(String error, AppLocale locale) {
    if (error.contains('not connected')) {
      return _text(
        locale,
        'Приложение не подключено к серверу.',
        'The app is not connected to the server.',
        'التطبيق غير متصل بالخادم.',
      );
    }
    return error.replaceFirst('Bad state: ', '');
  }
}

class _ProfileContent extends StatelessWidget {
  final UserProfile profile;
  final AppLocale locale;
  final VoidCallback onEditDetails;
  final VoidCallback onAddAddress;
  final ValueChanged<SavedAddress> onEditAddress;
  final ValueChanged<SavedAddress> onDeleteAddress;
  final VoidCallback onLanguage;
  final VoidCallback onTheme;
  final ThemeMode themeMode;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  const _ProfileContent({
    required this.profile,
    required this.locale,
    required this.onEditDetails,
    required this.onAddAddress,
    required this.onEditAddress,
    required this.onDeleteAddress,
    required this.onLanguage,
    required this.onTheme,
    required this.themeMode,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile.name.isEmpty ? locale.spicyGuest : profile.name;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth > 808
            ? (constraints.maxWidth - 760) / 2
            : 24.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 40),
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        profile.email,
                        style: GoogleFonts.inter(color: AppTheme.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _SectionTitle(
              text: _text(
                locale,
                'Личные данные',
                'Personal details',
                'البيانات الشخصية',
              ),
            ),
            _ProfileTile(
              icon: Icons.person_outline,
              title: _text(
                locale,
                'Имя и телефон',
                'Name and phone',
                'الاسم والهاتف',
              ),
              subtitle:
                  '$name\n${profile.phone.isEmpty ? _text(locale, 'Не указан', 'Not provided', 'غير مضاف') : profile.phone}',
              onTap: onEditDetails,
            ),
            _ProfileTile(
              icon: Icons.email_outlined,
              title: _text(
                locale,
                'Электронная почта',
                'Email',
                'البريد الإلكتروني',
              ),
              subtitle: profile.email,
              onTap: null,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _SectionTitle(
                    text: _text(
                      locale,
                      'Сохранённые адреса',
                      'Saved addresses',
                      'العناوين المحفوظة',
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: profile.savedAddresses.length >= 5
                      ? null
                      : onAddAddress,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_text(locale, 'Добавить', 'Add', 'إضافة')),
                ),
              ],
            ),
            if (profile.savedAddresses.isEmpty)
              _EmptyAddresses(onAddAddress: onAddAddress, locale: locale)
            else
              ...profile.savedAddresses.map(
                (address) => _AddressTile(
                  address: address,
                  locale: locale,
                  onTap: () => onEditAddress(address),
                  onDelete: () => onDeleteAddress(address),
                ),
              ),
            const SizedBox(height: 24),
            _SectionTitle(
              text: _text(locale, 'Настройки', 'Settings', 'الإعدادات'),
            ),
            _ProfileTile(
              icon: Icons.language_rounded,
              title: locale.language,
              subtitle: locale.languageName,
              onTap: onLanguage,
            ),
            _ProfileTile(
              icon: Icons.brightness_6_outlined,
              title: _text(locale, 'Оформление', 'Appearance', 'المظهر'),
              subtitle: _themeModeName(locale, themeMode),
              onTap: onTheme,
            ),
            _ProfileTile(
              icon: Icons.receipt_long_outlined,
              title: locale.orderHistory,
              subtitle: locale.viewPastOrders,
              onTap: () => context.push('/orders'),
            ),
            _ProfileTile(
              icon: Icons.rate_review_outlined,
              title: locale.myReviews,
              subtitle: locale.manageReviews,
              onTap: () => context.push('/reviews'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _StatCard(
                  label: locale.orders,
                  value: '${profile.totalOrders}',
                  icon: Icons.shopping_bag_outlined,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: locale.reviews,
                  value: '${profile.totalReviews}',
                  icon: Icons.star_outline_rounded,
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: Text(_text(locale, 'Выйти', 'Log out', 'تسجيل الخروج')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onDeleteAccount,
              child: Text(
                _text(
                  locale,
                  'Удалить аккаунт',
                  'Delete account',
                  'حذف الحساب',
                ),
                style: GoogleFonts.inter(color: AppTheme.error),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PersonalDetails {
  final String fullName;
  final String phone;
  const _PersonalDetails(this.fullName, this.phone);
}

class _PersonalDetailsSheet extends StatefulWidget {
  final UserProfile profile;
  const _PersonalDetailsSheet({required this.profile});
  @override
  State<_PersonalDetailsSheet> createState() => _PersonalDetailsSheetState();
}

class _PersonalDetailsSheetState extends State<_PersonalDetailsSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _phoneController = TextEditingController(text: widget.profile.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _text(
                locale,
                'Личные данные',
                'Personal details',
                'البيانات الشخصية',
              ),
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _text(locale, 'Имя', 'Name', 'الاسم'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: _text(locale, 'Телефон', 'Phone', 'الهاتف'),
                hintText: '+7 999 123 45 67',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                final name = _nameController.text.trim();
                final phone = _phoneController.text.trim();
                if (name.isEmpty || !_isValidRussianPhone(phone)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _text(
                          locale,
                          'Введите имя и российский номер телефона.',
                          'Enter your name and a Russian phone number.',
                          'أدخل الاسم ورقم هاتف روسي.',
                        ),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, _PersonalDetails(name, phone));
              },
              child: Text(_text(locale, 'Сохранить', 'Save', 'حفظ')),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressEditor extends StatefulWidget {
  final SavedAddress? address;
  const _AddressEditor({this.address});
  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  late final TextEditingController _labelController;
  late final TextEditingController _addressController;
  late final TextEditingController _apartmentController;
  late final TextEditingController _entranceController;
  late final TextEditingController _floorController;
  late final TextEditingController _notesController;
  late bool _isDefault;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    _labelController = TextEditingController(text: address?.label ?? 'Дом');
    _addressController = TextEditingController(
      text: address?.addressLine ?? '',
    );
    _apartmentController = TextEditingController(
      text: address?.apartment ?? '',
    );
    _entranceController = TextEditingController(text: address?.entrance ?? '');
    _floorController = TextEditingController(text: address?.floor ?? '');
    _notesController = TextEditingController(text: address?.notes ?? '');
    _isDefault = address?.isDefault ?? false;
    _latitude = address?.latitude;
    _longitude = address?.longitude;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _apartmentController.dispose();
    _entranceController.dispose();
    _floorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _chooseOnMap() async {
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => _MapLocationPicker(
          initialLocation: _latitude == null || _longitude == null
              ? null
              : LatLng(_latitude!, _longitude!),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _latitude = selected.latitude;
        _longitude = selected.longitude;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _text(
                locale,
                widget.address == null ? 'Новый адрес' : 'Изменить адрес',
                widget.address == null ? 'New address' : 'Edit address',
                widget.address == null ? 'عنوان جديد' : 'تعديل العنوان',
              ),
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                labelText: _text(
                  locale,
                  'Название: дом, работа',
                  'Label: home, work',
                  'الاسم: المنزل، العمل',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: _text(
                  locale,
                  'Улица, дом',
                  'Street and building',
                  'الشارع والبناء',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _apartmentController,
                    decoration: InputDecoration(
                      labelText: _text(
                        locale,
                        'Квартира',
                        'Apartment',
                        'الشقة',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _entranceController,
                    decoration: InputDecoration(
                      labelText: _text(locale, 'Подъезд', 'Entrance', 'المدخل'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _floorController,
                    decoration: InputDecoration(
                      labelText: _text(locale, 'Этаж', 'Floor', 'الطابق'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: _text(
                  locale,
                  'Комментарий курьеру',
                  'Delivery notes',
                  'ملاحظات التوصيل',
                ),
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _chooseOnMap,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                _latitude == null
                    ? _text(
                        locale,
                        'Выбрать точку на карте',
                        'Choose on map',
                        'اختيار الموقع على الخريطة',
                      )
                    : _text(
                        locale,
                        'Точка на карте выбрана',
                        'Map point selected',
                        'تم اختيار نقطة الخريطة',
                      ),
              ),
            ),
            if (_latitude != null && _longitude != null) ...[
              const SizedBox(height: 6),
              Text(
                '${_latitude!.toStringAsFixed(6)}, '
                '${_longitude!.toStringAsFixed(6)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF2E7D32),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              onChanged: (value) => setState(() => _isDefault = value),
              title: Text(
                _text(
                  locale,
                  'Адрес по умолчанию',
                  'Default address',
                  'العنوان الافتراضي',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                if (_labelController.text.trim().isEmpty ||
                    _addressController.text.trim().length < 3) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _text(
                          locale,
                          'Введите название и полный адрес.',
                          'Enter a label and full address.',
                          'أدخل الاسم والعنوان الكامل.',
                        ),
                      ),
                    ),
                  );
                  return;
                }
                if (_latitude == null || _longitude == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _text(
                          locale,
                          'Выберите точку на карте.',
                          'Choose a point on the map.',
                          'اختر نقطة على الخريطة.',
                        ),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  SavedAddress(
                    id: widget.address?.id ?? '',
                    label: _labelController.text.trim(),
                    addressLine: _addressController.text.trim(),
                    apartment: _apartmentController.text.trim(),
                    entrance: _entranceController.text.trim(),
                    floor: _floorController.text.trim(),
                    notes: _notesController.text.trim(),
                    latitude: _latitude,
                    longitude: _longitude,
                    isDefault: _isDefault,
                  ),
                );
              },
              child: Text(
                _text(locale, 'Сохранить адрес', 'Save address', 'حفظ العنوان'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;
  const _MapLocationPicker({this.initialLocation});
  @override
  State<_MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<_MapLocationPicker> {
  late LatLng _selected;
  late bool _hasSelection;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation ?? const LatLng(44.6098, 40.1005);
    _hasSelection = widget.initialLocation != null;
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _text(locale, 'Выберите точку', 'Choose a location', 'اختر الموقع'),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: 13,
              onTap: (_, point) {
                setState(() {
                  _selected = point;
                  _hasSelection = true;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.spicy.restaurant',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selected,
                    width: 52,
                    height: 52,
                    child: Icon(
                      Icons.location_pin,
                      size: 52,
                      color: _hasSelection
                          ? AppTheme.primary
                          : AppTheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      _hasSelection
                          ? Icons.check_circle
                          : Icons.touch_app_outlined,
                      color: _hasSelection
                          ? const Color(0xFF2E7D32)
                          : AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _hasSelection
                            ? _text(
                                locale,
                                'Точка выбрана. Подтвердите адрес.',
                                'Location selected. Confirm it below.',
                                'تم اختيار الموقع. أكّده أدناه.',
                              )
                            : _text(
                                locale,
                                'Нажмите на карту, чтобы поставить метку.',
                                'Tap the map to place the pin.',
                                'اضغط على الخريطة لوضع العلامة.',
                              ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _hasSelection
              ? () => Navigator.pop(context, _selected)
              : null,
          icon: const Icon(Icons.check),
          label: Text(
            _text(
              locale,
              'Использовать эту точку',
              'Use this location',
              'استخدم هذا الموقع',
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  final SavedAddress address;
  final AppLocale locale;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _AddressTile({
    required this.address,
    required this.locale,
    required this.onTap,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final detail = address.details;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(
          Icons.location_on_outlined,
          color: AppTheme.primary,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                address.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (address.isDefault)
              Chip(
                label: Text(_text(locale, 'Основной', 'Default', 'افتراضي')),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        subtitle: Text(
          '${address.addressLine}${detail.isEmpty ? '' : '\n$detail'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.error),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _EmptyAddresses extends StatelessWidget {
  final VoidCallback onAddAddress;
  final AppLocale locale;
  const _EmptyAddresses({required this.onAddAddress, required this.locale});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      border: Border.all(color: AppTheme.outline.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _text(
            locale,
            'Пока нет сохранённых адресов',
            'No saved addresses yet',
            'لا توجد عناوين محفوظة بعد',
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onAddAddress,
          icon: const Icon(Icons.add),
          label: Text(
            _text(locale, 'Добавить адрес', 'Add an address', 'أضف عنواناً'),
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.playfairDisplay(
      fontSize: 21,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    leading: Icon(icon, color: AppTheme.primary),
    title: Text(title),
    subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
  );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          Text(label, style: TextStyle(color: AppTheme.secondary)),
        ],
      ),
    ),
  );
}

String _text(AppLocale locale, String ru, String en, String ar) =>
    locale.text(ru: ru, en: en, ar: ar);

String _themeModeName(AppLocale locale, ThemeMode mode) => switch (mode) {
  ThemeMode.light => _text(locale, 'Светлая', 'Light', 'فاتح'),
  ThemeMode.dark => _text(locale, 'Тёмная', 'Dark', 'داكن'),
  ThemeMode.system => _text(
    locale,
    'Как в системе',
    'Use system setting',
    'حسب إعدادات الجهاز',
  ),
};

bool _isValidRussianPhone(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  return RegExp(r'^(7|8)\d{10}$').hasMatch(digits);
}
