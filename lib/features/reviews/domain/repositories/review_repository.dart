import 'package:spicy/features/reviews/domain/entities/review.dart';

abstract class ReviewRepository {
  Future<List<Review>> getAllReviews();
  Future<Review> submitReview({
    required String orderId,
    required String branchId,
    required int rating,
    required String comment,
  });
}
