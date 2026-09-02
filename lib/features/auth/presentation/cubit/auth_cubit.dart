import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spicy/features/auth/domain/entities/auth_user.dart';
import 'package:spicy/features/auth/domain/repositories/auth_repository.dart';
import 'package:spicy/features/auth/presentation/cubit/auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;
  late final StreamSubscription<AuthUser?> _authSubscription;

  AuthCubit({required this._repository}) : super(const AuthState()) {
    _authSubscription = _repository.authStateChanges.listen((user) {
      if (user == null) {
        emit(const AuthState(status: AuthStatus.unauthenticated));
      } else {
        emit(AuthState(status: AuthStatus.authenticated, user: user));
      }
    });
  }

  Future<void> restoreSession() async {
    try {
      final user = await _repository.restoreSession();
      emit(
        user.isNotEmpty
            ? AuthState(status: AuthStatus.authenticated, user: user)
            : const AuthState(status: AuthStatus.unauthenticated),
      );
    } catch (error) {
      emit(
        AuthState(status: AuthStatus.error, errorMessage: _errorMessage(error)),
      );
    }
  }

  Future<void> login({required String email, required String password}) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final user = await _repository.login(email: email, password: password);
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: _errorMessage(error),
        ),
      );
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final result = await _repository.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      emit(
        AuthState(
          status: result.requiresEmailConfirmation
              ? AuthStatus.emailConfirmationRequired
              : AuthStatus.authenticated,
          user: result.user,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: _errorMessage(e),
        ),
      );
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<bool> requestPasswordReset({required String email}) async {
    try {
      await _repository.requestPasswordReset(email: email);
      return true;
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: _errorMessage(error),
        ),
      );
      return false;
    }
  }

  void resetError() {
    emit(
      state.user.isNotEmpty
          ? AuthState(status: AuthStatus.authenticated, user: state.user)
          : const AuthState(status: AuthStatus.unauthenticated),
    );
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Future<void> close() async {
    await _authSubscription.cancel();
    return super.close();
  }
}
