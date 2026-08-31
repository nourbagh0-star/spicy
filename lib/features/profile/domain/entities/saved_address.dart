import 'package:equatable/equatable.dart';

class SavedAddress extends Equatable {
  final String id;
  final String label;
  final String addressLine;
  final String apartment;
  final String entrance;
  final String floor;
  final String notes;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.addressLine,
    this.apartment = '',
    this.entrance = '',
    this.floor = '',
    this.notes = '',
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  bool get hasMapLocation => latitude != null && longitude != null;

  String get details {
    final values = <String>[
      if (apartment.isNotEmpty) 'кв. $apartment',
      if (entrance.isNotEmpty) 'подъезд $entrance',
      if (floor.isNotEmpty) 'этаж $floor',
    ];
    return values.join(', ');
  }

  @override
  List<Object?> get props => [
    id,
    label,
    addressLine,
    apartment,
    entrance,
    floor,
    notes,
    latitude,
    longitude,
    isDefault,
  ];
}
