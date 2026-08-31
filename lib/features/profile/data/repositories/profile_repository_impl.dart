import 'package:spicy/features/profile/data/datasources/supabase_profile_data_source.dart';
import 'package:spicy/features/profile/domain/entities/saved_address.dart';
import 'package:spicy/features/profile/domain/entities/user_profile.dart';
import 'package:spicy/features/profile/domain/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseProfileDataSource _dataSource;

  ProfileRepositoryImpl({SupabaseClient? client})
    : _dataSource = SupabaseProfileDataSource(client: client);

  @override
  Future<UserProfile> getUserProfile() async {
    return _dataSource.getUserProfile();
  }

  @override
  Future<void> updatePersonalDetails({
    required String fullName,
    required String phone,
  }) {
    return _dataSource.updatePersonalDetails(fullName: fullName, phone: phone);
  }

  @override
  Future<void> saveAddress(SavedAddress address) {
    return _dataSource.saveAddress(address);
  }

  @override
  Future<void> deleteAddress(String addressId) {
    return _dataSource.deleteAddress(addressId);
  }

  @override
  Future<void> deleteAccount() {
    return _dataSource.deleteAccount();
  }
}
