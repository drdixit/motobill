class FuelType {
  final int? id;
  final String name;

  FuelType({this.id, required this.name});

  factory FuelType.fromJson(Map<String, dynamic> json) {
    return FuelType(id: json['id'] as int?, name: json['name'] as String);
  }
}
