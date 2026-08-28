import 'package:spicy/features/auth/domain/entities/auth_user.dart';
import 'package:spicy/features/auth/domain/entities/registration_result.dart';

abstract class AuthRepository {
  Future<AuthUser> login({required String email, required String password});
  Future<RegistrationResult> register({
    required String name,
    required String email,
    required String password,
    String phone,
  });
  Future<void> logout();
  Future<AuthUser> restoreSession();
  Stream<AuthUser?> get authStateChanges;
  AuthUser get currentUser;
  bool get isAuthenticated;
}
