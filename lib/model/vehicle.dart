class Vehicle {
  final int? id;
  final String name;
  final int? modelYear;
  final String? description;
  final String? image;
  final int manufacturerId;
  final int vehicleTypeId;
  final int fuelTypeId;
  final bool isEnabled;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Vehicle({
    this.id,
    required this.name,
    this.modelYear,
    this.description,
    this.image,
    required this.manufacturerId,
    required this.vehicleTypeId,
    required this.fuelTypeId,
    this.isEnabled = true,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as int?,
      name: json['name'] as String,
      modelYear: json['model_year'] as int?,
      description: json['description'] as String?,
      image: json['image'] as String?,
      manufacturerId: json['manufacturer_id'] as int,
      vehicleTypeId: json['vehicle_type_id'] as int,
      fuelTypeId: json['fuel_type_id'] as int,
      isEnabled: (json['is_enabled'] as int) == 1,
      isDeleted: (json['is_deleted'] as int) == 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'model_year': modelYear,
      'description': description,
      'image': image,
      'manufacturer_id': manufacturerId,
      'vehicle_type_id': vehicleTypeId,
      'fuel_type_id': fuelTypeId,
      'is_enabled': isEnabled ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  Vehicle copyWith({
    int? id,
    String? name,
    int? modelYear,
    String? description,
    String? image,
    int? manufacturerId,
    int? vehicleTypeId,
    int? fuelTypeId,
    bool? isEnabled,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      modelYear: modelYear ?? this.modelYear,
      description: description ?? this.description,
      image: image ?? this.image,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      vehicleTypeId: vehicleTypeId ?? this.vehicleTypeId,
      fuelTypeId: fuelTypeId ?? this.fuelTypeId,
      isEnabled: isEnabled ?? this.isEnabled,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
