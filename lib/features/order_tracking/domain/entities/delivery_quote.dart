import 'package:equatable/equatable.dart';

class DeliveryQuote extends Equatable {
  final String branchId;
  final String branchName;
  final String branchAddress;
  final int distanceMeters;
  final int deliveryFeeKopeks;
  final int minimumOrderKopeks;

  const DeliveryQuote({
    required this.branchId,
    required this.branchName,
    required this.branchAddress,
    required this.distanceMeters,
    required this.deliveryFeeKopeks,
    required this.minimumOrderKopeks,
  });

  double get deliveryFeeRubles => deliveryFeeKopeks / 100;
  double get minimumOrderRubles => minimumOrderKopeks / 100;
  String get distanceLabel => distanceMeters < 1000
      ? '$distanceMeters м'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} км';

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) => DeliveryQuote(
    branchId: json['branch_id'] as String,
    branchName: json['branch_name'] as String,
    branchAddress: json['branch_address'] as String,
    distanceMeters: json['distance_meters'] as int,
    deliveryFeeKopeks: json['delivery_fee_kopeks'] as int,
    minimumOrderKopeks: json['minimum_order_kopeks'] as int,
  );

  @override
  List<Object?> get props => [
    branchId,
    branchName,
    branchAddress,
    distanceMeters,
    deliveryFeeKopeks,
    minimumOrderKopeks,
  ];
}
