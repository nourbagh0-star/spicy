import 'package:spicy/features/profile/domain/entities/user_profile.dart';
import 'package:spicy/features/profile/domain/entities/saved_address.dart';

abstract class ProfileRepository {
  Future<UserProfile> getUserProfile();
  Future<void> updatePersonalDetails({
    required String fullName,
    required String phone,
  });
  Future<void> saveAddress(SavedAddress address);
  Future<void> deleteAddress(String addressId);
  Future<void> deleteAccount();
}
