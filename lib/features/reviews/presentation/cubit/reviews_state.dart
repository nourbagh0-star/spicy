import 'package:equatable/equatable.dart';
import 'package:spicy/features/reviews/domain/entities/review.dart';
import 'package:spicy/features/reviews/domain/entities/reviewable_order_item.dart';

abstract class ReviewsState extends Equatable {
  const ReviewsState();

  @override
  List<Object?> get props => [];
}

class ReviewsInitial extends ReviewsState {}

class ReviewsLoading extends ReviewsState {}

class ReviewsLoaded extends ReviewsState {
  final List<Review> reviews;

  const ReviewsLoaded(this.reviews);

  @override
  List<Object?> get props => [reviews];
}

class ReviewSubmitting extends ReviewsState {}

class ReviewSubmitted extends ReviewsState {
  final Review review;

  const ReviewSubmitted(this.review);

  @override
  List<Object?> get props => [review];
}

class ItemRatingsLoading extends ReviewsState {}

class ItemRatingsLoaded extends ReviewsState {
  final List<ReviewableOrderItem> items;

  const ItemRatingsLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class ItemRatingsSubmitting extends ReviewsState {
  final List<ReviewableOrderItem> items;

  const ItemRatingsSubmitting(this.items);

  @override
  List<Object?> get props => [items];
}

class ItemRatingsSubmitted extends ReviewsState {}

class ReviewsError extends ReviewsState {
  final String message;

  const ReviewsError(this.message);

  @override
  List<Object?> get props => [message];
}
