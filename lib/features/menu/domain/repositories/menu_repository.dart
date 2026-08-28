import 'package:spicy/features/menu/domain/entities/menu_item.dart';

abstract class MenuRepository {
  Future<List<MenuItem>> getMenuItems(String branchId);
}
