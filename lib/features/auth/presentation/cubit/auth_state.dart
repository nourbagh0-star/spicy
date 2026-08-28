import 'package:equatable/equatable.dart';
import 'package:spicy/features/auth/domain/entities/auth_user.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  emailConfirmationRequired,
  unauthenticated,
  error,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final AuthUser user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user = AuthUser.empty,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage];
}
