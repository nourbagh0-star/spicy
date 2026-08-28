import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:spicy/features/auth/domain/entities/auth_user.dart';
import 'package:spicy/features/auth/domain/entities/registration_result.dart';
import 'package:spicy/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient? client;
  AuthUser _currentUser = AuthUser.empty;

  AuthRepositoryImpl({this.client});

  @override
  AuthUser get currentUser {
    final user = client?.auth.currentUser;
    if (user != null) _currentUser = _mapUser(user);
    return _currentUser;
  }

  @override
  bool get isAuthenticated => client?.auth.currentSession != null;

  @override
  Stream<AuthUser?> get authStateChanges {
    final configuredClient = client;
    if (configuredClient == null) return Stream<AuthUser?>.value(null);

    return configuredClient.auth.onAuthStateChange.asyncMap((state) async {
      final user = state.session?.user;
      if (user == null) {
        _currentUser = AuthUser.empty;
        return null;
      }

      _currentUser = await _mapUserWithRole(user);
      return _currentUser;
    });
  }

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final client = _requireClient();
    final response = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Unable to start a signed-in session.');
    }

    _currentUser = await _mapUserWithRole(user);
    return _currentUser;
  }

  @override
  Future<RegistrationResult> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    final client = _requireClient();
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': name.trim(), 'contact_phone': phone.trim()},
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Unable to create the account.');
    }

    _currentUser = await _mapUserWithRole(
      user,
      fallbackName: name,
      phone: phone,
    );
    final requiresEmailConfirmation = response.session == null;

    if (!requiresEmailConfirmation && phone.trim().isNotEmpty) {
      await client
          .from('profiles')
          .update({'contact_phone': phone.trim()})
          .eq('id', user.id);
    }

    return RegistrationResult(
      user: _currentUser,
      requiresEmailConfirmation: requiresEmailConfirmation,
    );
  }

  @override
  Future<void> logout() async {
    await _requireClient().auth.signOut();
    _currentUser = AuthUser.empty;
  }

  @override
  Future<AuthUser> restoreSession() async {
    final client = _requireClient();
    final user = client.auth.currentSession?.user;
    _currentUser = user == null ? AuthUser.empty : await _mapUserWithRole(user);
    return _currentUser;
  }

  SupabaseClient _requireClient() {
    final configuredClient = client;
    if (configuredClient == null) {
      throw const AuthException(
        'This build is not connected to Supabase. Check the app configuration.',
      );
    }
    return configuredClient;
  }

  AuthUser _mapUser(User user, {String? fallbackName, String? phone}) {
    final metadataName = user.userMetadata?['full_name'] as String?;
    final metadataPhone = user.userMetadata?['contact_phone'] as String?;
    return AuthUser(
      id: user.id,
      name: (metadataName?.trim().isNotEmpty ?? false)
          ? metadataName!.trim()
          : fallbackName?.trim().isNotEmpty ?? false
          ? fallbackName!.trim()
          : user.email?.split('@').first ?? '',
      email: user.email ?? '',
      phone: phone?.trim() ?? metadataPhone?.trim() ?? '',
    );
  }

  Future<AuthUser> _mapUserWithRole(
    User user, {
    String? fallbackName,
    String? phone,
  }) async {
    final baseUser = _mapUser(user, fallbackName: fallbackName, phone: phone);
    try {
      final profile = await _requireClient()
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return AuthUser(
        id: baseUser.id,
        name: baseUser.name,
        email: baseUser.email,
        phone: baseUser.phone,
        role: profile?['role'] as String? ?? 'customer',
      );
    } catch (_) {
      return baseUser;
    }
  }
}
