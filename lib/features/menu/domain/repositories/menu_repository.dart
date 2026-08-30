import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/entities/branch_rating_summary.dart';

abstract class MenuRepository {
  Future<List<MenuItem>> getMenuItems(String branchId);
  Future<BranchRatingSummary> getBranchRatingSummary(String branchId);
}
