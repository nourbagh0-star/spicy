import 'package:equatable/equatable.dart';

/// A completed order line that the current customer may rate once.
class ReviewableOrderItem extends Equatable {
  final String orderItemId;
  final String name;
  final String variantName;
  final String imageUrl;
  final int quantity;
  final bool alreadyRated;

  const ReviewableOrderItem({
    required this.orderItemId,
    required this.name,
    required this.variantName,
    required this.imageUrl,
    required this.quantity,
    required this.alreadyRated,
  });

  @override
  List<Object?> get props => [
    orderItemId,
    name,
    variantName,
    imageUrl,
    quantity,
    alreadyRated,
  ];
}
