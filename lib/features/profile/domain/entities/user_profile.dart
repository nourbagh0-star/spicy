import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String? avatarUrl;
  final int totalOrders;
  final int totalReviews;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.address = '',
    this.avatarUrl,
    this.totalOrders = 0,
    this.totalReviews = 0,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        phone,
        address,
        avatarUrl,
        totalOrders,
        totalReviews,
      ];
}
