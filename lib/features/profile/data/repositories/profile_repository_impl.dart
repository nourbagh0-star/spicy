import 'package:spicy/features/profile/data/datasources/mock_profile_data_source.dart';
import 'package:spicy/features/profile/domain/entities/user_profile.dart';
import 'package:spicy/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final MockProfileDataSource _dataSource;

  ProfileRepositoryImpl({MockProfileDataSource? dataSource})
      : _dataSource = dataSource ?? MockProfileDataSource();

  @override
  Future<UserProfile> getUserProfile() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _dataSource.getUserProfile();
  }

  @override
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _dataSource.updateUserProfile(profile);
  }
}
