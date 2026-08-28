import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_variant.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_modifier.dart';

class SupabaseMenuDataSource {
  final SupabaseClient? client;
  final AppLocale locale;

  SupabaseMenuDataSource({required this.client, required this.locale});

  Future<List<MenuItem>> getMenuItems(String branchId) async {
    final results = await Future.wait([
      _requireClient().rpc(
        'get_branch_menu',
        params: {
          'p_branch_id': branchId,
          'p_language_code': locale.languageCode,
        },
      ),
      _requireClient().rpc(
        'get_branch_menu_modifiers',
        params: {
          'p_branch_id': branchId,
          'p_language_code': locale.languageCode,
        },
      ),
    ]);
    final rows = results[0] as List<dynamic>;
    final modifiersByItem = <String, List<MenuItemModifierGroup>>{};
    for (final row in results[1] as List<dynamic>) {
      final data = row as Map<String, dynamic>;
      final itemId = data['menu_item_id'] as String;
      final groups = (data['modifier_groups'] as List<dynamic>? ?? const [])
          .map((group) {
            final groupData = group as Map<String, dynamic>;
            return MenuItemModifierGroup(
              id: groupData['id'] as String,
              name: groupData['name'] as String,
              minimumSelections: groupData['minimum_selections'] as int,
              maximumSelections: groupData['maximum_selections'] as int,
              options: (groupData['options'] as List<dynamic>? ?? const [])
                  .map((option) {
                    final optionData = option as Map<String, dynamic>;
                    return MenuItemModifierOption(
                      id: optionData['id'] as String,
                      name: optionData['name'] as String,
                      priceKopeks: optionData['price_kopeks'] as int,
                    );
                  })
                  .toList(growable: false),
            );
          })
          .toList(growable: false);
      modifiersByItem[itemId] = groups;
    }

    final byId = <String, _MenuItemBuilder>{};
    for (final row in rows) {
      final data = row as Map<String, dynamic>;
      final itemId = data['menu_item_id'] as String;
      final builder = byId.putIfAbsent(itemId, () => _MenuItemBuilder(data));
      builder.addVariant(data);
    }

    return byId.values
        .map(
          (builder) => builder.build(modifiersByItem[builder.id] ?? const []),
        )
        .toList(growable: false);
  }

  SupabaseClient _requireClient() {
    final configuredClient = client;
    if (configuredClient == null) {
      throw StateError(
        'This build is not connected to Supabase. Check the app configuration.',
      );
    }
    return configuredClient;
  }
}

class _MenuItemBuilder {
  final Map<String, dynamic> _item;
  final List<MenuItemVariant> _variants = [];

  _MenuItemBuilder(this._item);

  String get id => _item['menu_item_id'] as String;

  void addVariant(Map<String, dynamic> row) {
    _variants.add(
      MenuItemVariant(
        id: row['variant_id'] as String,
        name: row['variant_name'] as String,
        code: row['variant_code'] as String,
        priceKopeks: row['price_kopeks'] as int,
      ),
    );
  }

  MenuItem build(List<MenuItemModifierGroup> modifierGroups) {
    return MenuItem(
      id: _item['menu_item_id'] as String,
      name: _item['item_name'] as String,
      description: _item['item_description'] as String? ?? '',
      displayPrice: '',
      prices: _variants.map((variant) => variant.priceRubles).toList(),
      variants: List.unmodifiable(_variants),
      heatLevel: _item['heat_level'] as int? ?? 0,
      image: (_item['storage_path'] ?? _item['image_url']) as String? ?? '',
      category: _item['category_name'] as String,
      sandwichType: _item['sandwich_type'] as String?,
      modifierGroups: modifierGroups,
    );
  }
}
