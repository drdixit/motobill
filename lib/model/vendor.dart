class Vendor {
  final int? id;
  final String name;
  final String? legalName;
  final String? phone;
  final String? email;
  final String? gstNumber;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;
  final bool isEnabled;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Vendor({
    this.id,
    required this.name,
    this.legalName,
    this.phone,
    this.email,
    this.gstNumber,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
    this.isEnabled = true,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] as int?,
      name: json['name'] as String,
      legalName: json['legal_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      gstNumber: json['gst_number'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
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
      'legal_name': legalName,
      'phone': phone,
      'email': email,
      'gst_number': gstNumber,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'pincode': pincode,
      'is_enabled': isEnabled ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  Vendor copyWith({
    int? id,
    String? name,
    String? legalName,
    String? phone,
    String? email,
    String? gstNumber,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? pincode,
    bool? isEnabled,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      legalName: legalName ?? this.legalName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstNumber: gstNumber ?? this.gstNumber,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      isEnabled: isEnabled ?? this.isEnabled,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
