import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/repositories/menu_repository.dart';
import 'package:spicy/features/menu/presentation/cubit/menu_state.dart';

class MenuCubit extends Cubit<MenuState> {
  static const sandwichTypes = <String>[
    'chicken',
    'lamb',
    'beef',
    'sandwiches',
  ];
  final MenuRepository _repository;

  MenuCubit({required this._repository}) : super(MenuInitial());

  List<MenuItem> _allItems = const [];

  Future<List<MenuItem>> loadMenu(String branchId) async {
    emit(MenuLoading());
    try {
      _allItems = await _repository.getMenuItems(branchId);
      final categories = _categoriesFrom(_allItems);
      emit(MenuLoaded(items: _allItems, categories: categories));
      return _allItems;
    } catch (e) {
      emit(MenuError(e.toString()));
      rethrow;
    }
  }

  void filterByCategory(String category) {
    final currentState = state;
    if (currentState is MenuLoaded) {
      final categoryItems = category == 'All'
          ? _allItems
          : _allItems
                .where((item) => item.category == category)
                .toList(growable: false);
      final hasSandwichGroups = categoryItems.any(
        (item) => item.sandwichType != null,
      );
      final selectedType = hasSandwichGroups ? sandwichTypes.first : null;
      emit(
        MenuLoaded(
          items: selectedType == null
              ? categoryItems
              : categoryItems
                    .where((item) => item.sandwichType == selectedType)
                    .toList(growable: false),
          categories: currentState.categories,
          selectedCategory: category,
          sandwichTypes: hasSandwichGroups ? sandwichTypes : const [],
          selectedSandwichType: selectedType,
        ),
      );
    }
  }

  void filterBySandwichType(String sandwichType) {
    final currentState = state;
    if (currentState is! MenuLoaded ||
        !currentState.sandwichTypes.contains(sandwichType)) {
      return;
    }
    emit(
      MenuLoaded(
        items: _allItems
            .where(
              (item) =>
                  item.category == currentState.selectedCategory &&
                  item.sandwichType == sandwichType,
            )
            .toList(growable: false),
        categories: currentState.categories,
        selectedCategory: currentState.selectedCategory,
        sandwichTypes: currentState.sandwichTypes,
        selectedSandwichType: sandwichType,
      ),
    );
  }

  List<String> _categoriesFrom(List<MenuItem> items) {
    final categories = <String>['All'];
    for (final item in items) {
      if (!categories.contains(item.category)) categories.add(item.category);
    }
    return List.unmodifiable(categories);
  }
}
