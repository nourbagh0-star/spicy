import 'package:spicy/features/profile/domain/entities/user_profile.dart';

class MockProfileDataSource {
  UserProfile _profile = const UserProfile(
    id: 'usr-001',
    name: 'Nour',
    email: 'nour@epicurean.com',
    phone: '+966 50 123 4567',
    address: '123 Olaya Street, Riyadh, Saudi Arabia',
    totalOrders: 12,
    totalReviews: 5,
  );

  UserProfile getUserProfile() => _profile;

  UserProfile updateUserProfile(UserProfile profile) {
    _profile = profile;
    return _profile;
  }
}
