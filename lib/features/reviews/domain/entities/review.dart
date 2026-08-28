import 'package:equatable/equatable.dart';

class Review extends Equatable {
  final String id;
  final String orderId;
  final String branchId;
  final String userName;
  final String? userAvatarUrl;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.orderId,
    required this.branchId,
    required this.userName,
    this.userAvatarUrl,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    orderId,
    branchId,
    userName,
    userAvatarUrl,
    rating,
    comment,
    createdAt,
  ];
}
