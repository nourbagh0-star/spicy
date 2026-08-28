import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spicy/features/reviews/domain/repositories/review_repository.dart';
import 'package:spicy/features/reviews/presentation/cubit/reviews_state.dart';

class ReviewsCubit extends Cubit<ReviewsState> {
  final ReviewRepository _repository;

  ReviewsCubit({required this._repository}) : super(ReviewsInitial());

  Future<void> loadAllReviews() async {
    emit(ReviewsLoading());
    try {
      final reviews = await _repository.getAllReviews();
      emit(ReviewsLoaded(reviews));
    } catch (e) {
      emit(ReviewsError(e.toString()));
    }
  }

  Future<void> submitReview({
    required String orderId,
    required String branchId,
    required int rating,
    required String comment,
  }) async {
    emit(ReviewSubmitting());
    try {
      final submitted = await _repository.submitReview(
        orderId: orderId,
        branchId: branchId,
        rating: rating,
        comment: comment,
      );
      emit(ReviewSubmitted(submitted));
    } catch (e) {
      emit(ReviewsError(e.toString()));
    }
  }
}
