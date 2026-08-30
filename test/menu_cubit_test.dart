import 'package:flutter_test/flutter_test.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/entities/branch_rating_summary.dart';
import 'package:spicy/features/menu/domain/repositories/menu_repository.dart';
import 'package:spicy/features/menu/presentation/cubit/menu_cubit.dart';
import 'package:spicy/features/menu/presentation/cubit/menu_state.dart';

void main() {
  group('MenuCubit sandwich filters', () {
    late MenuCubit cubit;

    setUp(() {
      cubit = MenuCubit(repository: _FakeMenuRepository(_items));
    });

    tearDown(() => cubit.close());

    test(
      'selecting sandwiches defaults to chicken without an all filter',
      () async {
        await cubit.loadMenu('branch');

        cubit.filterByCategory('SANDWICHES');

        final state = cubit.state as MenuLoaded;
        expect(state.sandwichTypes, MenuCubit.sandwichTypes);
        expect(state.selectedSandwichType, 'chicken');
        expect(state.items.map((item) => item.id), ['chicken']);
        expect(state.sandwichTypes, isNot(contains('all')));
      },
    );

    test('switches to the selected sandwich group', () async {
      await cubit.loadMenu('branch');
      cubit.filterByCategory('SANDWICHES');

      cubit.filterBySandwichType('beef');

      final state = cubit.state as MenuLoaded;
      expect(state.selectedSandwichType, 'beef');
      expect(state.items.map((item) => item.id), ['beef']);
    });

    test('ordinary categories have no sandwich filters', () async {
      await cubit.loadMenu('branch');

      cubit.filterByCategory('PIZZA');

      final state = cubit.state as MenuLoaded;
      expect(state.sandwichTypes, isEmpty);
      expect(state.selectedSandwichType, isNull);
      expect(state.items.map((item) => item.id), ['pizza']);
    });
  });
}

const _items = <MenuItem>[
  MenuItem(
    id: 'chicken',
    name: 'Chicken',
    description: '',
    displayPrice: '',
    prices: [1],
    heatLevel: 0,
    image: '',
    category: 'SANDWICHES',
    sandwichType: 'chicken',
  ),
  MenuItem(
    id: 'lamb',
    name: 'Lamb',
    description: '',
    displayPrice: '',
    prices: [1],
    heatLevel: 0,
    image: '',
    category: 'SANDWICHES',
    sandwichType: 'lamb',
  ),
  MenuItem(
    id: 'beef',
    name: 'Beef',
    description: '',
    displayPrice: '',
    prices: [1],
    heatLevel: 0,
    image: '',
    category: 'SANDWICHES',
    sandwichType: 'beef',
  ),
  MenuItem(
    id: 'sandwiches',
    name: 'Sandwiches',
    description: '',
    displayPrice: '',
    prices: [1],
    heatLevel: 0,
    image: '',
    category: 'SANDWICHES',
    sandwichType: 'sandwiches',
  ),
  MenuItem(
    id: 'pizza',
    name: 'Pizza',
    description: '',
    displayPrice: '',
    prices: [1],
    heatLevel: 0,
    image: '',
    category: 'PIZZA',
  ),
];

class _FakeMenuRepository implements MenuRepository {
  final List<MenuItem> items;

  const _FakeMenuRepository(this.items);

  @override
  Future<List<MenuItem>> getMenuItems(String branchId) async => items;

  @override
  Future<BranchRatingSummary> getBranchRatingSummary(String branchId) async =>
      const BranchRatingSummary();
}
