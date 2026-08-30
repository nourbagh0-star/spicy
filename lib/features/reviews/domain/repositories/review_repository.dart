import 'package:spicy/features/reviews/domain/entities/review.dart';
import 'package:spicy/features/reviews/domain/entities/reviewable_order_item.dart';

abstract class ReviewRepository {
  Future<List<Review>> getAllReviews();
  Future<Review> submitReview({
    required String orderId,
    required String branchId,
    required int rating,
    required String comment,
  });
  Future<List<ReviewableOrderItem>> getReviewableOrderItems(
    String orderId,
    String languageCode,
  );
  Future<void> submitItemRatings({
    required String orderId,
    required Map<String, int> ratings,
  });
}
