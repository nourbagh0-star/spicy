import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';

class ManagerMenuAvailabilityScreen extends StatefulWidget {
  const ManagerMenuAvailabilityScreen({super.key});

  @override
  State<ManagerMenuAvailabilityScreen> createState() =>
      _ManagerMenuAvailabilityScreenState();
}

class _ManagerMenuAvailabilityScreenState
    extends State<ManagerMenuAvailabilityScreen> {
  late Future<_AvailabilityData> _data = _load();
  String _filter = 'all';

  Future<_AvailabilityData> _load() async {
    final db = Supabase.instance.client;
    final profile = await db
        .from('profiles')
        .select('assigned_branch_id')
        .eq('id', db.auth.currentUser!.id)
        .single();
    final branchId = profile['assigned_branch_id'] as String?;
    if (branchId == null) throw StateError('manager_branch_not_assigned');

    final categories = List<Map<String, dynamic>>.from(
      await db
          .from('menu_category_translations')
          .select('category_id,name')
          .eq('language_code', 'ru')
          .order('name'),
    );
    final categoryRows = List<Map<String, dynamic>>.from(
      await db
          .from('branch_menu_categories')
          .select('category_id,is_available')
          .eq('branch_id', branchId),
    );
    final itemRows = List<Map<String, dynamic>>.from(
      await db.from('menu_items').select('id,category_id'),
    );
    final names = List<Map<String, dynamic>>.from(
      await db
          .from('menu_item_translations')
          .select('menu_item_id,name')
          .eq('language_code', 'ru'),
    );
    final variantNames = List<Map<String, dynamic>>.from(
      await db
          .from('menu_item_variant_translations')
          .select('menu_item_variant_id,name')
          .eq('language_code', 'ru'),
    );
    final variants = List<Map<String, dynamic>>.from(
      await db
          .from('branch_menu_item_variants')
          .select('menu_item_id,menu_item_variant_id,is_available')
          .eq('branch_id', branchId),
    );
    final categoryByItem = {
      for (final item in itemRows)
        item['id'] as String: item['category_id'] as String,
    };
    final itemNameById = {
      for (final name in names)
        name['menu_item_id'] as String: name['name'] as String,
    };
    final variantNameById = {
      for (final name in variantNames)
        name['menu_item_variant_id'] as String: name['name'] as String,
    };
    return _AvailabilityData(
      branchId: branchId,
      categories: categories,
      categoryRows: categoryRows,
      lines: variants
          .map(
            (row) => _AvailabilityLine(
              itemId: row['menu_item_id'] as String,
              variantId: row['menu_item_variant_id'] as String,
              categoryId: categoryByItem[row['menu_item_id'] as String]!,
              itemName: itemNameById[row['menu_item_id'] as String] ?? 'Блюдо',
              variantName:
                  variantNameById[row['menu_item_variant_id'] as String] ??
                  'Вариант',
              isAvailable: row['is_available'] as bool,
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          locale.text(
            ru: 'Наличие меню',
            en: 'Menu availability',
            ar: 'توفر القائمة',
          ),
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<_AvailabilityData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final message =
                snapshot.error.toString().contains(
                  'manager_branch_not_assigned',
                )
                ? locale.text(
                    ru: 'Вам ещё не назначили филиал. Обратитесь к владельцу.',
                    en: 'A branch has not been assigned to you yet. Contact the owner.',
                    ar: 'لم يتم تعيين فرع لك بعد. تواصل مع المالك.',
                  )
                : snapshot.error.toString();
            return Center(child: Text(message, textAlign: TextAlign.center));
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          final data = snapshot.data!;
          final lines = data.lines
              .where((line) {
                if (_filter == 'available') return line.isAvailable;
                if (_filter == 'unavailable') return !line.isAvailable;
                return true;
              })
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                locale.text(
                  ru: 'Изменения действуют только для вашего филиала.',
                  en: 'Changes apply only to your branch.',
                  ar: 'التغييرات تنطبق على فرعك فقط.',
                ),
                style: GoogleFonts.inter(color: AppTheme.secondary),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _filter,
                decoration: InputDecoration(
                  labelText: locale.text(ru: 'Показать', en: 'Show', ar: 'عرض'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(
                      locale.text(
                        ru: 'Все блюда',
                        en: 'All items',
                        ar: 'كل الأصناف',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'available',
                    child: Text(
                      locale.text(ru: 'Есть', en: 'Available', ar: 'متاح'),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'unavailable',
                    child: Text(
                      locale.text(ru: 'Нет', en: 'Unavailable', ar: 'غير متاح'),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _filter = value!),
              ),
              const SizedBox(height: 20),
              Text(
                locale.text(ru: 'Разделы', en: 'Categories', ar: 'الأقسام'),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ...data.categories.map((category) {
                final row = data.categoryRows.firstWhere(
                  (row) => row['category_id'] == category['category_id'],
                );
                final enabled = row['is_available'] as bool;
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(category['name'] as String),
                  subtitle: Text(
                    enabled
                        ? locale.text(
                            ru: 'Раздел открыт',
                            en: 'Category open',
                            ar: 'القسم مفتوح',
                          )
                        : locale.text(
                            ru: 'Раздел закрыт',
                            en: 'Category closed',
                            ar: 'القسم مغلق',
                          ),
                  ),
                  value: enabled,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (value) async {
                    await Supabase.instance.client
                        .from('branch_menu_categories')
                        .update({'is_available': value})
                        .eq('branch_id', data.branchId)
                        .eq('category_id', category['category_id']);
                    if (mounted) {
                      setState(() {
                        _data = _load();
                      });
                    }
                  },
                );
              }),
              const Divider(),
              const SizedBox(height: 14),
              Text(
                locale.text(ru: 'Блюда', en: 'Items', ar: 'الأصناف'),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ...lines.map(
                (line) => Card(
                  child: SwitchListTile(
                    title: Text(line.itemName),
                    subtitle: Text(
                      '${line.variantName} · ${line.isAvailable ? locale.text(ru: 'Есть', en: 'Available', ar: 'متاح') : locale.text(ru: 'Нет', en: 'Unavailable', ar: 'غير متاح')}',
                    ),
                    value: line.isAvailable,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (value) async {
                      await Supabase.instance.client
                          .from('branch_menu_item_variants')
                          .update({'is_available': value})
                          .eq('branch_id', data.branchId)
                          .eq('menu_item_variant_id', line.variantId);
                      if (mounted) {
                        setState(() {
                          _data = _load();
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AvailabilityData {
  final String branchId;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> categoryRows;
  final List<_AvailabilityLine> lines;
  const _AvailabilityData({
    required this.branchId,
    required this.categories,
    required this.categoryRows,
    required this.lines,
  });
}

class _AvailabilityLine {
  final String itemId;
  final String variantId;
  final String categoryId;
  final String itemName;
  final String variantName;
  final bool isAvailable;
  const _AvailabilityLine({
    required this.itemId,
    required this.variantId,
    required this.categoryId,
    required this.itemName,
    required this.variantName,
    required this.isAvailable,
  });
}
