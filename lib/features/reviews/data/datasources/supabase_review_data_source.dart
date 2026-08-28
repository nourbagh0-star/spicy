import 'package:spicy/features/reviews/domain/entities/review.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseReviewDataSource {
  final SupabaseClient? client;

  const SupabaseReviewDataSource({required this.client});

  Future<List<Review>> getAllReviews() async {
    final rows = await _client
        .from('order_reviews')
        .select('id, order_id, branch_id, rating, comment, created_at')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => _toReview(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Review> submitReview({
    required String orderId,
    required String branchId,
    required int rating,
    required String comment,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Please sign in to leave a review.');
    final row = await _client
        .from('order_reviews')
        .insert({
          'order_id': orderId,
          'branch_id': branchId,
          'customer_id': userId,
          'rating': rating,
          'comment': comment.trim(),
        })
        .select('id, order_id, branch_id, rating, comment, created_at')
        .single();
    return _toReview(row);
  }

  Review _toReview(Map<String, dynamic> row) => Review(
    id: row['id'] as String,
    orderId: row['order_id'] as String,
    branchId: row['branch_id'] as String,
    userName: 'Гость Spicy',
    rating: (row['rating'] as num).toDouble(),
    comment: row['comment'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  SupabaseClient get _client =>
      client ?? (throw StateError('This build is not connected to Supabase.'));
}
