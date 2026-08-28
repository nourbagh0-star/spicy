import 'package:equatable/equatable.dart';

class MenuItemVariant extends Equatable {
  final String id;
  final String name;
  final String code;
  final int priceKopeks;

  const MenuItemVariant({
    required this.id,
    required this.name,
    required this.code,
    required this.priceKopeks,
  });

  double get priceRubles => priceKopeks / 100;

  @override
  List<Object?> get props => [id, name, code, priceKopeks];
}
