import 'package:equatable/equatable.dart';
import 'package:spicy/features/profile/domain/entities/saved_address.dart';

class UserProfile extends Equatable {
  final String id;
  final String name;
  final String email;
  final String phone;
  final List<SavedAddress> savedAddresses;
  final int totalOrders;
  final int totalReviews;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.savedAddresses = const [],
    this.totalOrders = 0,
    this.totalReviews = 0,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    phone,
    savedAddresses,
    totalOrders,
    totalReviews,
  ];
}
