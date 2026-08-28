import 'package:spicy/features/menu/data/datasources/supabase_menu_data_source.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/repositories/menu_repository.dart';

class MenuRepositoryImpl implements MenuRepository {
  final SupabaseMenuDataSource _dataSource;

  MenuRepositoryImpl({required this._dataSource});

  @override
  Future<List<MenuItem>> getMenuItems(String branchId) {
    return _dataSource.getMenuItems(branchId);
  }
}
