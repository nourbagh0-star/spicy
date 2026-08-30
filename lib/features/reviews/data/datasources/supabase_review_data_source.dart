import 'package:spicy/features/reviews/domain/entities/review.dart';
import 'package:spicy/features/reviews/domain/entities/reviewable_order_item.dart';
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

  Future<List<ReviewableOrderItem>> getReviewableOrderItems(
    String orderId,
    String languageCode,
  ) async {
    final rows =
        await _client.rpc(
              'get_order_item_rating_choices',
              params: {'p_order_id': orderId, 'p_language_code': languageCode},
            )
            as List<dynamic>;
    return rows
        .map((row) {
          final data = row as Map<String, dynamic>;
          return ReviewableOrderItem(
            orderItemId: data['order_item_id'] as String,
            name: data['item_name'] as String,
            variantName: data['variant_name'] as String? ?? '',
            imageUrl: data['image_url'] as String? ?? '',
            quantity: data['quantity'] as int,
            alreadyRated: data['already_rated'] as bool,
          );
        })
        .toList(growable: false);
  }

  Future<void> submitItemRatings({
    required String orderId,
    required Map<String, int> ratings,
  }) {
    return _client.rpc(
      'submit_order_item_ratings',
      params: {
        'p_order_id': orderId,
        'p_ratings': ratings.entries
            .map((entry) => {'order_item_id': entry.key, 'rating': entry.value})
            .toList(growable: false),
      },
    );
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
