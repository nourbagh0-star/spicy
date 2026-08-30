import 'package:spicy/features/reviews/data/datasources/supabase_review_data_source.dart';
import 'package:spicy/features/reviews/domain/entities/review.dart';
import 'package:spicy/features/reviews/domain/entities/reviewable_order_item.dart';
import 'package:spicy/features/reviews/domain/repositories/review_repository.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final SupabaseReviewDataSource _dataSource;

  ReviewRepositoryImpl({required this._dataSource});

  @override
  Future<List<Review>> getAllReviews() async {
    return _dataSource.getAllReviews();
  }

  @override
  Future<Review> submitReview({
    required String orderId,
    required String branchId,
    required int rating,
    required String comment,
  }) {
    return _dataSource.submitReview(
      orderId: orderId,
      branchId: branchId,
      rating: rating,
      comment: comment,
    );
  }

  @override
  Future<List<ReviewableOrderItem>> getReviewableOrderItems(
    String orderId,
    String languageCode,
  ) {
    return _dataSource.getReviewableOrderItems(orderId, languageCode);
  }

  @override
  Future<void> submitItemRatings({
    required String orderId,
    required Map<String, int> ratings,
  }) {
    return _dataSource.submitItemRatings(orderId: orderId, ratings: ratings);
  }
}
