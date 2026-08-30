import 'package:equatable/equatable.dart';

/// Aggregate branch rating that is safe to display to signed-in customers.
/// It deliberately contains no reviewer identity or review text.
class BranchRatingSummary extends Equatable {
  final double averageRating;
  final int reviewCount;

  const BranchRatingSummary({this.averageRating = 0, this.reviewCount = 0});

  bool get hasRatings => reviewCount > 0;

  @override
  List<Object?> get props => [averageRating, reviewCount];
}
