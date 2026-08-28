import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spicy/features/branch/domain/entities/branch.dart';
import 'package:spicy/features/branch/domain/repositories/branch_repository.dart';

class SupabaseBranchRepository implements BranchRepository {
  final SupabaseClient? client;

  SupabaseBranchRepository({required this.client});

  @override
  Future<List<Branch>> getActiveBranches() async {
    final client = _requireClient();
    final rows = await client
        .from('branches')
        .select('id, name, address, map_reference_url')
        .eq('is_active', true)
        .order('name');

    return (rows as List<dynamic>)
        .map((row) => Branch.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  SupabaseClient _requireClient() {
    final configuredClient = client;
    if (configuredClient == null) {
      throw StateError(
        'This build is not connected to Supabase. Check the app configuration.',
      );
    }
    return configuredClient;
  }
}
