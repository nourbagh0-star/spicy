import 'package:spicy/features/branch/domain/entities/branch.dart';

abstract class BranchRepository {
  Future<List<Branch>> getActiveBranches();
}
