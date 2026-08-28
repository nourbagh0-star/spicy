import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spicy/features/branch/domain/entities/branch.dart';
import 'package:spicy/features/branch/domain/repositories/branch_repository.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_state.dart';

class BranchCubit extends Cubit<BranchState> {
  final BranchRepository repository;

  BranchCubit({required this.repository}) : super(BranchInitial());

  Future<void> loadBranches() async {
    emit(BranchLoading());
    try {
      final branches = await repository.getActiveBranches();
      emit(BranchLoaded(branches: branches));
    } catch (error) {
      emit(BranchError(_messageFor(error)));
    }
  }

  void selectBranch(Branch branch) {
    final current = state;
    if (current is! BranchLoaded) return;
    emit(BranchLoaded(branches: current.branches, selectedBranch: branch));
  }

  String _messageFor(Object error) {
    return error is StateError
        ? error.message
        : 'Could not load restaurant branches. Please try again.';
  }
}
