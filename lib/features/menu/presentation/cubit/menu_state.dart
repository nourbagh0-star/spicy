import 'package:equatable/equatable.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/entities/branch_rating_summary.dart';

abstract class MenuState extends Equatable {
  const MenuState();

  @override
  List<Object?> get props => [];
}

class MenuInitial extends MenuState {}

class MenuLoading extends MenuState {}

class MenuLoaded extends MenuState {
  final List<MenuItem> items;
  final List<String> categories;
  final String selectedCategory;
  final List<String> sandwichTypes;
  final String? selectedSandwichType;
  final BranchRatingSummary branchRating;

  const MenuLoaded({
    required this.items,
    required this.categories,
    this.selectedCategory = 'All',
    this.sandwichTypes = const [],
    this.selectedSandwichType,
    this.branchRating = const BranchRatingSummary(),
  });

  @override
  List<Object?> get props => [
    items,
    categories,
    selectedCategory,
    sandwichTypes,
    selectedSandwichType,
    branchRating,
  ];
}

class MenuError extends MenuState {
  final String message;

  const MenuError(this.message);

  @override
  List<Object?> get props => [message];
}
