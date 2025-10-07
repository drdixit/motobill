class VehicleType {
  final int? id;
  final String name;

  VehicleType({this.id, required this.name});

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(id: json['id'] as int?, name: json['name'] as String);
  }
}
