import 'package:equatable/equatable.dart';
import 'package:spicy/features/auth/domain/entities/auth_user.dart';

class RegistrationResult extends Equatable {
  final AuthUser user;
  final bool requiresEmailConfirmation;

  const RegistrationResult({
    required this.user,
    required this.requiresEmailConfirmation,
  });

  @override
  List<Object?> get props => [user, requiresEmailConfirmation];
}
