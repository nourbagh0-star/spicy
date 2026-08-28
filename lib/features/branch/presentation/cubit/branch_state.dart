import 'package:equatable/equatable.dart';
import 'package:spicy/features/branch/domain/entities/branch.dart';

sealed class BranchState extends Equatable {
  const BranchState();

  @override
  List<Object?> get props => [];
}

class BranchInitial extends BranchState {}

class BranchLoading extends BranchState {}

class BranchLoaded extends BranchState {
  final List<Branch> branches;
  final Branch? selectedBranch;

  const BranchLoaded({required this.branches, this.selectedBranch});

  @override
  List<Object?> get props => [branches, selectedBranch];
}

class BranchError extends BranchState {
  final String message;

  const BranchError(this.message);

  @override
  List<Object?> get props => [message];
}
