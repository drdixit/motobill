class CompanyInfo {
  final int? id;
  final String name;
  final String legalName;
  final String? gstNumber;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;
  final String? phone;
  final String? email;
  final String? logo;
  final bool isEnabled;
  final bool isDeleted;
  final bool isPrimary;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CompanyInfo({
    this.id,
    required this.name,
    required this.legalName,
    this.gstNumber,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
    this.phone,
    this.email,
    this.logo,
    this.isEnabled = true,
    this.isDeleted = false,
    this.isPrimary = false,
    this.createdAt,
    this.updatedAt,
  });

  factory CompanyInfo.fromJson(Map<String, dynamic> json) {
    return CompanyInfo(
      id: json['id'] as int?,
      name: json['name'] as String,
      legalName: json['legal_name'] as String,
      gstNumber: json['gst_number'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      logo: json['logo'] as String?,
      isEnabled: (json['is_enabled'] as int) == 1,
      isDeleted: (json['is_deleted'] as int) == 1,
      isPrimary: (json['is_primary'] as int) == 1,
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
      'gst_number': gstNumber,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'pincode': pincode,
      'phone': phone,
      'email': email,
      'logo': logo,
      'is_enabled': isEnabled ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'is_primary': isPrimary ? 1 : 0,
    };
  }
}
