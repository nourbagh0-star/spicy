import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';

class JsonMenuDataSource {
  static const _dataBaseUrl =
      'https://raw.githubusercontent.com/nourbagh0-star/spicy-menu-data/main';
  static final _menuDataUri = Uri.parse('$_dataBaseUrl/menu-data.json');
  static const _fallbackAssetPath = 'lib/menu-data.json';

  final AppLocale _locale;
  List<MenuItem>? _cachedItems;
  List<String>? _cachedCategories;

  JsonMenuDataSource({required this._locale});

  Future<void> _loadData() async {
    if (_cachedItems != null) return;

    try {
      final jsonData = await _loadMenuJson();
      final List<dynamic> categoriesData = jsonData['categories'];

      final List<MenuItem> items = [];
      final Set<String> categories = {};

      for (final catData in categoriesData) {
        final originalCatName = catData['name'] as String;
        final categoryName = _locale.translateCategory(originalCatName);
        categories.add(categoryName);

        final itemsData = catData['items'] as List<dynamic>;
        for (final itemData in itemsData) {
          final List<double> prices = (itemData['prices'] as List<dynamic>)
              .map((p) => (p as num).toDouble())
              .toList();

          // Handle missing or empty prices safely
          final priceList = prices.isNotEmpty ? prices : [0.0];

          // The API stores repository image paths relative to its base URL.
          String imageUrl = itemData['image'] as String? ?? '';
          if (imageUrl.startsWith('/')) {
            imageUrl = '$_dataBaseUrl$imageUrl';
          }

          items.add(
            MenuItem(
              id: itemData['id'],
              name: itemData['name'],
              description: itemData['description'] ?? '',
              displayPrice:
                  itemData['displayPrice'] ?? '${priceList.first} руб',
              prices: priceList,
              heatLevel: itemData['heatLevel'] ?? 0,
              image: imageUrl,
              category: categoryName,
              sandwichType: originalCatName == 'СЭНДВИЧИ'
                  ? _sandwichTypeCode(itemData['sandwichType'] as String?)
                  : null,
              rating:
                  4.5 + (itemData['id'].hashCode % 10) / 20.0, // fake rating
              reviewCount: 10 + (itemData['id'].hashCode % 100),
              isPopular: (itemData['id'].hashCode % 10) > 7,
            ),
          );
        }
      }

      _cachedItems = items;
      _cachedCategories = categories.toList();
    } catch (e) {
      throw Exception('Failed to load menu data: $e');
    }
  }

  String _sandwichTypeCode(String? value) {
    switch (value) {
      case 'БАРАНИНА':
        return 'lamb';
      case 'ГОВЯДИНА':
        return 'beef';
      case 'СЭНДВИЧИ':
        return 'sandwiches';
      case 'КУРИЦА':
      case null:
        return 'chicken';
      default:
        return 'chicken';
    }
  }

  Future<Map<String, dynamic>> _loadMenuJson() async {
    try {
      final response = await http
          .get(_menuDataUri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Menu API returned ${response.statusCode}');
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Menu API returned an invalid JSON object');
      }
      return decoded;
    } catch (_) {
      // The bundled copy keeps the menu usable when the API is unavailable.
      final jsonString = await rootBundle.loadString(_fallbackAssetPath);
      return json.decode(jsonString) as Map<String, dynamic>;
    }
  }

  Future<List<MenuItem>> getMenuItems() async {
    await _loadData();
    return _cachedItems!;
  }

  Future<List<MenuItem>> getMenuItemsByCategory(String category) async {
    await _loadData();
    return _cachedItems!.where((item) => item.category == category).toList();
  }

  Future<List<String>> getCategories() async {
    await _loadData();
    return _cachedCategories!;
  }
}
