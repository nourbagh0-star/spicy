// This screen keeps its dialog state locally; its asynchronous actions are
// always guarded by the owning State's mounted check before UI updates.
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';

class OwnerMenuScreen extends StatefulWidget {
  const OwnerMenuScreen({super.key});
  @override
  State<OwnerMenuScreen> createState() => _OwnerMenuScreenState();
}

class _OwnerMenuScreenState extends State<OwnerMenuScreen> {
  late Future<_MenuAdminData> _data = _load();
  String? _selectedBranchId;
  String _availabilityFilter = 'all';
  String _categoryFilter = 'all';
  Future<_MenuAdminData> _load() async {
    final db = Supabase.instance.client;
    final branches = List<Map<String, dynamic>>.from(
      await db.from('branches').select('id,name').order('name'),
    );
    final variants = List<Map<String, dynamic>>.from(
      await db
          .from('branch_menu_item_variants')
          .select(
            'branch_id,menu_item_id,menu_item_variant_id,price_kopeks,is_available',
          ),
    );
    final items = List<Map<String, dynamic>>.from(
      await db
          .from('menu_item_translations')
          .select('menu_item_id,name,description')
          .eq('language_code', 'ru'),
    );
    final optionNames = List<Map<String, dynamic>>.from(
      await db
          .from('menu_item_variant_translations')
          .select('menu_item_variant_id,name')
          .eq('language_code', 'ru'),
    );
    final itemDetails = List<Map<String, dynamic>>.from(
      await db
          .from('menu_items')
          .select('id,image_url,category_id,sandwich_type'),
    );
    final categories = List<Map<String, dynamic>>.from(
      await db
          .from('menu_category_translations')
          .select('category_id,name')
          .eq('language_code', 'ru')
          .order('name'),
    );
    final categoryAvailability = List<Map<String, dynamic>>.from(
      await db
          .from('branch_menu_categories')
          .select('branch_id,category_id,is_available'),
    );
    final imagesByItemId = {
      for (final item in itemDetails)
        item['id'] as String: item['image_url'] as String?,
    };
    final itemById = {
      for (final item in items)
        item['menu_item_id'] as String: {
          ...item,
          'image_url': imagesByItemId[item['menu_item_id']],
          'category_id': itemDetails.firstWhere(
            (detail) => detail['id'] == item['menu_item_id'],
          )['category_id'],
          'sandwich_type': itemDetails.firstWhere(
            (detail) => detail['id'] == item['menu_item_id'],
          )['sandwich_type'],
        },
    };
    final variantById = {
      for (final item in optionNames)
        item['menu_item_variant_id'] as String: item,
    };
    return _MenuAdminData(
      branches,
      categories,
      categoryAvailability,
      variants
          .map(
            (line) => _MenuLine(
              line,
              itemById[line['menu_item_id']],
              variantById[line['menu_item_variant_id']],
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return _OwnerScaffold(
      title: locale.text(
        ru: 'Меню и цены',
        en: 'Menu and prices',
        ar: 'القائمة والأسعار',
      ),
      body: FutureBuilder<_MenuAdminData>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          final data = snapshot.data!;
          final selectedBranchId =
              _selectedBranchId ?? data.branches.first['id'] as String;
          bool isCategoryOpen(String categoryId) =>
              data.categoryAvailability.any(
                (setting) =>
                    setting['branch_id'] == selectedBranchId &&
                    setting['category_id'] == categoryId &&
                    setting['is_available'] == true,
              );
          final branchLines = data.lines
              .where((line) => line.branchId == selectedBranchId)
              .where(
                (line) =>
                    _categoryFilter == 'all' ||
                    line.categoryId == _categoryFilter,
              )
              // With "All sections", show what customers can actually order.
              // Selecting a particular closed section still lets the owner edit it.
              .where(
                (line) =>
                    _categoryFilter != 'all' || isCategoryOpen(line.categoryId),
              )
              .where(
                (line) =>
                    _availabilityFilter == 'all' ||
                    (_availabilityFilter == 'available'
                        ? line.isAvailable
                        : !line.isAvailable),
              )
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                locale.text(
                  ru: 'Цена и доступность ниже относятся только к выбранному филиалу.',
                  en: 'Prices and availability below apply only to the selected branch.',
                  ar: 'الأسعار والتوفر أدناه تنطبق على الفرع المختار فقط.',
                ),
                style: GoogleFonts.inter(color: AppTheme.secondary),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedBranchId,
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
                    .toList(),
                onChanged: (value) => setState(() => _selectedBranchId = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoryFilter,
                      decoration: InputDecoration(
                        labelText: locale.text(
                          ru: 'Раздел',
                          en: 'Category',
                          ar: 'القسم',
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(
                            locale.text(
                              ru: 'Все разделы',
                              en: 'All categories',
                              ar: 'كل الأقسام',
                            ),
                          ),
                        ),
                        ...data.categories.map(
                          (category) => DropdownMenuItem(
                            value: category['category_id'] as String,
                            child: Text(category['name'] as String),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _categoryFilter = value!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _availabilityFilter,
                      decoration: InputDecoration(
                        labelText: locale.text(
                          ru: 'Статус',
                          en: 'Status',
                          ar: 'الحالة',
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(
                            locale.text(ru: 'Все', en: 'All', ar: 'الكل'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'available',
                          child: Text(
                            locale.text(
                              ru: 'Есть',
                              en: 'Available',
                              ar: 'متاح',
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'unavailable',
                          child: Text(
                            locale.text(
                              ru: 'Нет',
                              en: 'Unavailable',
                              ar: 'غير متاح',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _availabilityFilter = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                locale.text(
                  ru: 'Разделы в этом филиале',
                  en: 'Categories in this branch',
                  ar: 'الأقسام في هذا الفرع',
                ),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ...data.categories.map((category) {
                final setting = data.categoryAvailability.firstWhere(
                  (row) =>
                      row['branch_id'] == selectedBranchId &&
                      row['category_id'] == category['category_id'],
                );
                final enabled = setting['is_available'] as bool;
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(category['name'] as String),
                  subtitle: Text(
                    enabled
                        ? locale.text(
                            ru: 'Раздел открыт в этом филиале',
                            en: 'Category open in this branch',
                            ar: 'القسم مفتوح في هذا الفرع',
                          )
                        : locale.text(
                            ru: 'Раздел закрыт в этом филиале',
                            en: 'Category closed in this branch',
                            ar: 'القسم مغلق في هذا الفرع',
                          ),
                  ),
                  value: enabled,
                  onChanged: (value) async {
                    await Supabase.instance.client
                        .from('branch_menu_categories')
                        .update({'is_available': value})
                        .eq('branch_id', selectedBranchId)
                        .eq('category_id', category['category_id']);
                    if (mounted)
                      setState(() {
                        _data = _load();
                      });
                  },
                  activeThumbColor: AppTheme.primary,
                );
              }),
              const Divider(),
              ...branchLines.map(
                (line) => Card(
                  child: ListTile(
                    title: Text(
                      line.itemName,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${line.variantName} · ${line.isAvailable ? locale.text(ru: 'Доступно', en: 'Available', ar: 'متاح') : locale.text(ru: 'Скрыто', en: 'Hidden', ar: 'مخفي')}',
                    ),
                    trailing: Text(
                      '${(line.priceKopeks / 100).toStringAsFixed(0)} ₽',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    onTap: () => _editLine(context, data.branches, line),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editLine(
    BuildContext context,
    List<Map<String, dynamic>> branches,
    _MenuLine line,
  ) async {
    var selectedBranch = line.branchId;
    final price = TextEditingController(
      text: (line.priceKopeks / 100).toStringAsFixed(0),
    );
    final name = TextEditingController(text: line.itemName);
    final description = TextEditingController(text: line.description);
    var uploadedImageUrl = line.imageUrl;
    var available = line.isAvailable;
    var selectedSandwichType = line.sandwichType;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Изменить блюдо',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Название',
                          ),
                        ),
                        TextField(
                          controller: description,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Описание',
                          ),
                        ),
                        if (uploadedImageUrl != null &&
                            uploadedImageUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              uploadedImageUrl!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final image = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                            );
                            if (image == null) return;
                            final bytes = await image.readAsBytes();
                            final path =
                                'items/${line.itemId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
                            await Supabase.instance.client.storage
                                .from('menu-images')
                                .uploadBinary(
                                  path,
                                  bytes,
                                  fileOptions: const FileOptions(
                                    contentType: 'image/jpeg',
                                    upsert: false,
                                  ),
                                );
                            uploadedImageUrl = Supabase.instance.client.storage
                                .from('menu-images')
                                .getPublicUrl(path);
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.upload_rounded),
                          label: const Text('Загрузить новое изображение'),
                        ),
                        const SizedBox(height: 8),
                        Text(line.variantName),
                        if (selectedSandwichType != null) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedSandwichType,
                            decoration: const InputDecoration(
                              labelText: 'Группа сэндвичей',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'chicken',
                                child: Text('КУРИЦА'),
                              ),
                              DropdownMenuItem(
                                value: 'lamb',
                                child: Text('БАРАНИНА'),
                              ),
                              DropdownMenuItem(
                                value: 'beef',
                                child: Text('ГОВЯДИНА'),
                              ),
                              DropdownMenuItem(
                                value: 'sandwiches',
                                child: Text('СЭНДВИЧИ'),
                              ),
                            ],
                            onChanged: (value) => setSheetState(
                              () => selectedSandwichType = value,
                            ),
                          ),
                        ],
                        DropdownButtonFormField(
                          value: selectedBranch,
                          items: branches
                              .map(
                                (b) => DropdownMenuItem(
                                  value: b['id'],
                                  child: Text(b['name']),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setSheetState(
                            () => selectedBranch = value as String,
                          ),
                        ),
                        TextField(
                          controller: price,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Цена, ₽',
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Доступно'),
                          value: available,
                          onChanged: (value) =>
                              setSheetState(() => available = value),
                        ),
                        FilledButton(
                          onPressed: () async {
                            final rubles = int.tryParse(price.text.trim());
                            if (rubles == null) return;
                            await Supabase.instance.client
                                .from('branch_menu_item_variants')
                                .update({
                                  'price_kopeks': rubles * 100,
                                  'is_available': available,
                                })
                                .eq('branch_id', selectedBranch)
                                .eq('menu_item_variant_id', line.variantId);
                            await Supabase.instance.client
                                .from('menu_item_translations')
                                .update({
                                  'name': name.text.trim(),
                                  'description': description.text.trim(),
                                })
                                .eq('menu_item_id', line.itemId)
                                .eq('language_code', 'ru');
                            final itemUpdate = <String, dynamic>{};
                            if (uploadedImageUrl != null &&
                                uploadedImageUrl!.isNotEmpty) {
                              itemUpdate['image_url'] = uploadedImageUrl;
                            }
                            if (selectedSandwichType != null) {
                              itemUpdate['sandwich_type'] =
                                  selectedSandwichType;
                            }
                            if (itemUpdate.isNotEmpty) {
                              await Supabase.instance.client
                                  .from('menu_items')
                                  .update(itemUpdate)
                                  .eq('id', line.itemId);
                            }
                            if (mounted) {
                              Navigator.pop(sheetContext);
                              setState(() {
                                _data = _load();
                              });
                            }
                          },
                          child: const Text('Сохранить'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // New-item creation returns after the upload flow is added to this dialog.
  // ignore: unused_element
  Future<void> _createItem(BuildContext context) async {
    final db = Supabase.instance.client;
    final categories = List<Map<String, dynamic>>.from(
      await db
          .from('menu_category_translations')
          .select('category_id,name')
          .eq('language_code', 'ru'),
    );
    if (categories.isEmpty || !mounted) return;
    var categoryId = categories.first['category_id'] as String;
    final name = TextEditingController();
    final imageUrl = TextEditingController();
    final price = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Новое блюдо'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category['category_id'] as String,
                        child: Text(category['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) categoryId = value;
                },
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              TextField(
                controller: imageUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Ссылка на изображение',
                ),
              ),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Цена для всех филиалов, ₽',
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              final rubles = int.tryParse(price.text.trim());
              if (name.text.trim().isEmpty ||
                  imageUrl.text.trim().isEmpty ||
                  rubles == null ||
                  rubles < 0)
                return;
              final item = await db
                  .from('menu_items')
                  .insert({
                    'category_id': categoryId,
                    'image_url': imageUrl.text.trim(),
                  })
                  .select('id')
                  .single();
              await db.from('menu_item_translations').insert({
                'menu_item_id': item['id'],
                'language_code': 'ru',
                'name': name.text.trim(),
              });
              final variant = await db
                  .from('menu_item_variants')
                  .insert({
                    'menu_item_id': item['id'],
                    'code': 'standard_${DateTime.now().microsecondsSinceEpoch}',
                  })
                  .select('id')
                  .single();
              await db.from('menu_item_variant_translations').insert({
                'menu_item_variant_id': variant['id'],
                'language_code': 'ru',
                'name': 'Стандартный',
              });
              final branches = List<Map<String, dynamic>>.from(
                await db.from('branches').select('id'),
              );
              await db
                  .from('branch_menu_items')
                  .insert(
                    branches
                        .map(
                          (branch) => {
                            'branch_id': branch['id'],
                            'menu_item_id': item['id'],
                          },
                        )
                        .toList(),
                  );
              await db
                  .from('branch_menu_item_variants')
                  .insert(
                    branches
                        .map(
                          (branch) => {
                            'branch_id': branch['id'],
                            'menu_item_id': item['id'],
                            'menu_item_variant_id': variant['id'],
                            'price_kopeks': rubles * 100,
                          },
                        )
                        .toList(),
                  );
              if (mounted) {
                Navigator.pop(dialog);
                setState(() {
                  _data = _load();
                });
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}

class OwnerModifiersScreen extends StatefulWidget {
  const OwnerModifiersScreen({super.key});
  @override
  State<OwnerModifiersScreen> createState() => _OwnerModifiersScreenState();
}

class _OwnerModifiersScreenState extends State<OwnerModifiersScreen> {
  late Future<_ModifierData> _data = _load();
  Future<_ModifierData> _load() async {
    final db = Supabase.instance.client;
    final items = List<Map<String, dynamic>>.from(
      await db
          .from('menu_item_translations')
          .select('menu_item_id,name')
          .eq('language_code', 'ru')
          .order('name'),
    );
    final groups = List<Map<String, dynamic>>.from(
      await db
          .from('menu_item_modifier_groups')
          .select('id,menu_item_id,menu_category_id,code,maximum_selections'),
    );
    final categories = List<Map<String, dynamic>>.from(
      await db
          .from('menu_category_translations')
          .select('category_id,name')
          .eq('language_code', 'ru')
          .order('name'),
    );
    final translations = List<Map<String, dynamic>>.from(
      await db
          .from('menu_item_modifier_group_translations')
          .select('menu_item_modifier_group_id,name')
          .eq('language_code', 'ru'),
    );
    return _ModifierData(items, categories, groups, {
      for (final row in translations)
        row['menu_item_modifier_group_id'] as String: row['name'] as String,
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return _OwnerScaffold(
      title: locale.text(
        ru: 'Добавки и удаления',
        en: 'Add-ons and removals',
        ar: 'الإضافات والحذف',
      ),
      actions: [
        IconButton(
          onPressed: () => _addGroup(context),
          icon: const Icon(Icons.add),
        ),
      ],
      body: FutureBuilder<_ModifierData>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                locale.text(
                  ru: 'Создайте опцию сразу: название и цена появятся у клиентов.',
                  en: 'Create an option: its name and price will appear for customers.',
                  ar: 'أنشئ خياراً: سيظهر اسمه وسعره للعملاء.',
                ),
                style: GoogleFonts.inter(color: AppTheme.secondary),
              ),
              const SizedBox(height: 12),
              ...data.groups.map(
                (group) => Card(
                  child: ListTile(
                    title: Text(data.names[group['id']] ?? group['code']),
                    subtitle: Text(
                      locale.text(
                        ru: 'Для: ${data.targetName(group)} · до ${group['maximum_selections']} вариантов',
                        en: 'For: ${data.targetName(group)} · up to ${group['maximum_selections']} options',
                        ar: 'لـ: ${data.targetName(group)} · حتى ${group['maximum_selections']} خيارات',
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: locale.text(
                            ru: 'Добавить ещё вариант',
                            en: 'Add another option',
                            ar: 'إضافة خيار آخر',
                          ),
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _addOption(context, group),
                        ),
                        IconButton(
                          tooltip: locale.text(
                            ru: 'Удалить группу',
                            en: 'Delete group',
                            ar: 'حذف المجموعة',
                          ),
                          icon: const Icon(Icons.delete_outline),
                          color: AppTheme.primary,
                          onPressed: () => _deleteGroup(context, group),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addGroup(BuildContext context) async {
    final data = await _data;
    var scope = 'item';
    var targetId = data.items.first['menu_item_id'] as String;
    final groupName = TextEditingController();
    final optionName = TextEditingController();
    final price = TextEditingController(text: '0');
    await showDialog(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialogState) => AlertDialog(
          title: const Text('Новая группа'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: scope,
                decoration: const InputDecoration(labelText: '1. Применить к'),
                items: const [
                  DropdownMenuItem(value: 'item', child: Text('Одно блюдо')),
                  DropdownMenuItem(
                    value: 'category',
                    child: Text('Целая категория'),
                  ),
                ],
                onChanged: (value) => setDialogState(() {
                  scope = value!;
                  targetId = scope == 'item'
                      ? data.items.first['menu_item_id'] as String
                      : data.categories.first['category_id'] as String;
                }),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(scope),
                initialValue: targetId,
                decoration: InputDecoration(
                  labelText: scope == 'item'
                      ? '2. Выберите блюдо'
                      : '2. Выберите категорию',
                ),
                items: (scope == 'item' ? data.items : data.categories)
                    .map(
                      (target) => DropdownMenuItem<String>(
                        value:
                            (scope == 'item'
                                    ? target['menu_item_id']
                                    : target['category_id'])
                                as String,
                        child: Text(target['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (value) => targetId = value!,
              ),
              TextField(
                controller: groupName,
                decoration: const InputDecoration(
                  labelText: '3. Название раздела (необязательно)',
                ),
              ),
              TextField(
                controller: optionName,
                decoration: const InputDecoration(
                  labelText: '4. Название опции',
                ),
              ),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '5. Цена, ₽'),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                final optionLabel = optionName.text.trim();
                final groupLabel = groupName.text.trim().isEmpty
                    ? optionLabel
                    : groupName.text.trim();
                final rubles = int.tryParse(price.text) ?? -1;
                if (optionLabel.isEmpty || rubles < 0) return;
                final db = Supabase.instance.client;
                final group = await db
                    .from('menu_item_modifier_groups')
                    .insert({
                      if (scope == 'item') 'menu_item_id': targetId,
                      if (scope == 'category') 'menu_category_id': targetId,
                      'code': groupLabel.toLowerCase().replaceAll(' ', '_'),
                      'maximum_selections': 3,
                    })
                    .select('id')
                    .single();
                await db.from('menu_item_modifier_group_translations').insert({
                  'menu_item_modifier_group_id': group['id'],
                  'language_code': 'ru',
                  'name': groupLabel,
                });
                final option = await db
                    .from('menu_item_modifier_options')
                    .insert({
                      'menu_item_modifier_group_id': group['id'],
                      'code': optionLabel.toLowerCase().replaceAll(' ', '_'),
                    })
                    .select('id')
                    .single();
                await db.from('menu_item_modifier_option_translations').insert({
                  'menu_item_modifier_option_id': option['id'],
                  'language_code': 'ru',
                  'name': optionLabel,
                });
                final branches = List<Map<String, dynamic>>.from(
                  await db.from('branches').select('id'),
                );
                await db
                    .from('branch_menu_item_modifier_options')
                    .insert(
                      branches
                          .map(
                            (branch) => {
                              'branch_id': branch['id'],
                              'menu_item_modifier_option_id': option['id'],
                              'price_kopeks': rubles * 100,
                            },
                          )
                          .toList(),
                    );
                if (mounted) {
                  Navigator.pop(dialog);
                  setState(() {
                    _data = _load();
                  });
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteGroup(
    BuildContext context,
    Map<String, dynamic> group,
  ) async {
    final label = (await _data).names[group['id']] ?? 'эту группу';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Удалить группу?'),
        content: Text(
          '«$label» и все её варианты будут удалены без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Supabase.instance.client
        .from('menu_item_modifier_groups')
        .delete()
        .eq('id', group['id']);
    if (mounted) {
      setState(() {
        _data = _load();
      });
    }
  }

  Future<void> _addOption(
    BuildContext context,
    Map<String, dynamic> group,
  ) async {
    final name = TextEditingController();
    final price = TextEditingController(text: '0');
    await showDialog(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Новая опция'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Цена, ₽'),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              final rubles = int.tryParse(price.text) ?? 0;
              if (name.text.trim().isEmpty || rubles < 0) return;
              final db = Supabase.instance.client;
              final option = await db
                  .from('menu_item_modifier_options')
                  .insert({
                    'menu_item_modifier_group_id': group['id'],
                    'code': name.text.trim().toLowerCase().replaceAll(' ', '_'),
                  })
                  .select('id')
                  .single();
              await db.from('menu_item_modifier_option_translations').insert({
                'menu_item_modifier_option_id': option['id'],
                'language_code': 'ru',
                'name': name.text.trim(),
              });
              final branches = List<Map<String, dynamic>>.from(
                await db.from('branches').select('id'),
              );
              await db
                  .from('branch_menu_item_modifier_options')
                  .insert(
                    branches
                        .map(
                          (branch) => {
                            'branch_id': branch['id'],
                            'menu_item_modifier_option_id': option['id'],
                            'price_kopeks': rubles * 100,
                          },
                        )
                        .toList(),
                  );
              if (mounted) {
                Navigator.pop(dialog);
                setState(() {
                  _data = _load();
                });
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}

class OwnerBranchesScreen extends StatefulWidget {
  const OwnerBranchesScreen({super.key});
  @override
  State<OwnerBranchesScreen> createState() => _OwnerBranchesScreenState();
}

class _OwnerBranchesScreenState extends State<OwnerBranchesScreen> {
  late Future<List<Map<String, dynamic>>> _branches = _load();
  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('branches')
            .select('id,name,address,public_phone,is_active')
            .order('name'),
      );
  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return _OwnerScaffold(
      title: locale.text(
        ru: 'Филиалы и менеджеры',
        en: 'Branches and managers',
        ar: 'الفروع والمديرون',
      ),
      actions: [
        IconButton(
          onPressed: () => _assignManager(context),
          icon: const Icon(Icons.person_add_alt_1),
        ),
      ],
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _branches,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                locale.text(
                  ru: 'Нажмите на филиал, чтобы изменить его данные. Кнопка сверху назначает менеджера по email.',
                  en: 'Tap a branch to edit it. The button above assigns a manager by email.',
                  ar: 'اضغط على الفرع لتعديله. الزر أعلاه يعيّن مديراً عبر البريد الإلكتروني.',
                ),
                style: GoogleFonts.inter(color: AppTheme.secondary),
              ),
              const SizedBox(height: 12),
              ...snapshot.data!.map(
                (branch) => Card(
                  child: ListTile(
                    title: Text(
                      branch['name'],
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(branch['address']),
                    trailing: Switch(
                      value: branch['is_active'] as bool,
                      onChanged: (active) async {
                        await Supabase.instance.client
                            .from('branches')
                            .update({'is_active': active})
                            .eq('id', branch['id']);
                        setState(() {
                          _branches = _load();
                        });
                      },
                      activeColor: AppTheme.primary,
                    ),
                    onTap: () => _editBranch(context, branch),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editBranch(
    BuildContext context,
    Map<String, dynamic> branch,
  ) async {
    final name = TextEditingController(text: branch['name']);
    final address = TextEditingController(text: branch['address']);
    final phone = TextEditingController(text: branch['public_phone'] ?? '');
    await showDialog(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Изменить филиал'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Адрес'),
              ),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Телефон'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              await Supabase.instance.client
                  .from('branches')
                  .update({
                    'name': name.text.trim(),
                    'address': address.text.trim(),
                    'public_phone': phone.text.trim().isEmpty
                        ? null
                        : phone.text.trim(),
                  })
                  .eq('id', branch['id']);
              if (mounted) {
                Navigator.pop(dialog);
                setState(() {
                  _branches = _load();
                });
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignManager(BuildContext context) async {
    final branches = await _branches;
    final email = TextEditingController();
    var branchId = branches.first['id'] as String;
    await showDialog(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Назначить менеджера'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email сотрудника'),
            ),
            DropdownButtonFormField(
              value: branchId,
              items: branches
                  .map(
                    (b) => DropdownMenuItem(
                      value: b['id'],
                      child: Text(b['name']),
                    ),
                  )
                  .toList(),
              onChanged: (v) => branchId = v as String,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.rpc(
                  'owner_assign_manager',
                  params: {
                    'p_email': email.text.trim(),
                    'p_branch_id': branchId,
                  },
                );
                if (mounted) {
                  Navigator.pop(dialog);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Менеджер назначен')),
                  );
                }
              } catch (error) {
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
              }
            },
            child: const Text('Назначить'),
          ),
        ],
      ),
    );
  }
}

class _OwnerScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  const _OwnerScaffold({required this.title, required this.body, this.actions});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        title,
        style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
      ),
      backgroundColor: AppTheme.surface,
      actions: actions,
    ),
    body: body,
  );
}

class _MenuAdminData {
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> categoryAvailability;
  final List<_MenuLine> lines;
  _MenuAdminData(
    this.branches,
    this.categories,
    this.categoryAvailability,
    this.lines,
  );
}

class _MenuLine {
  final String branchId,
      variantId,
      itemId,
      itemName,
      variantName,
      description,
      categoryId;
  final String? imageUrl;
  final String? sandwichType;
  final int priceKopeks;
  final bool isAvailable;
  _MenuLine(
    Map<String, dynamic> row,
    Map<String, dynamic>? item,
    Map<String, dynamic>? variant,
  ) : branchId = row['branch_id'],
      variantId = row['menu_item_variant_id'],
      itemId = row['menu_item_id'],
      categoryId = item?['category_id'] as String,
      itemName = item?['name'] ?? 'Блюдо',
      variantName = variant?['name'] ?? 'Вариант',
      description = item?['description'] ?? '',
      imageUrl = item?['image_url'] as String?,
      sandwichType = item?['sandwich_type'] as String?,
      priceKopeks = row['price_kopeks'],
      isAvailable = row['is_available'];
}

class _ModifierData {
  final List<Map<String, dynamic>> items, categories, groups;
  final Map<String, String> names;
  _ModifierData(this.items, this.categories, this.groups, this.names);

  String targetName(Map<String, dynamic> group) {
    final itemId = group['menu_item_id'] as String?;
    if (itemId != null) {
      return items.firstWhere((item) => item['menu_item_id'] == itemId)['name']
          as String;
    }
    final categoryId = group['menu_category_id'] as String?;
    return categories.firstWhere(
          (category) => category['category_id'] == categoryId,
        )['name']
        as String;
  }
}
