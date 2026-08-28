import 'package:spicy/features/reviews/data/datasources/supabase_review_data_source.dart';
import 'package:spicy/features/reviews/domain/entities/review.dart';
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
}
