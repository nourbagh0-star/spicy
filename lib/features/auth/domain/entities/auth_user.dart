import 'package:equatable/equatable.dart';

class AuthUser extends Equatable {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = 'customer',
  });

  static const empty = AuthUser(id: '', name: '', email: '');

  bool get isEmpty => this == empty;
  bool get isNotEmpty => this != empty;

  bool get isOwner => role == 'owner';
  bool get isManager => role == 'manager';

  @override
  List<Object?> get props => [id, name, email, phone, role];
}
