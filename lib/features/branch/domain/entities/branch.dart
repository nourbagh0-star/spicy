import 'package:equatable/equatable.dart';

class Branch extends Equatable {
  final String id;
  final String name;
  final String address;
  final String? mapReferenceUrl;

  const Branch({
    required this.id,
    required this.name,
    required this.address,
    this.mapReferenceUrl,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      mapReferenceUrl: json['map_reference_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name, address, mapReferenceUrl];
}
