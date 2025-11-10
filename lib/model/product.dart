class Product {
  final int? id;
  final String name;
  final String? partNumber;
  final String? description;
  final int hsnCodeId;
  final int uqcId;
  final double costPrice;
  final double sellingPrice;
  final double? mrp;
  final int subCategoryId;
  final int manufacturerId;
  final bool isTaxable;
  final bool negativeAllow;
  final bool isEnabled;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    this.id,
    required this.name,
    this.partNumber,
    this.description,
    required this.hsnCodeId,
    required this.uqcId,
    required this.costPrice,
    required this.sellingPrice,
    this.mrp,
    required this.subCategoryId,
    required this.manufacturerId,
    this.isTaxable = true,
    this.negativeAllow = false,
    this.isEnabled = true,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int?,
      name: json['name'] as String,
      partNumber: json['part_number'] as String?,
      description: json['description'] as String?,
      hsnCodeId: json['hsn_code_id'] as int,
      uqcId: json['uqc_id'] as int,
      costPrice: (json['cost_price'] as num).toDouble(),
      sellingPrice: (json['selling_price'] as num).toDouble(),
      mrp: json['mrp'] != null ? (json['mrp'] as num).toDouble() : null,
      subCategoryId: json['sub_category_id'] as int,
      manufacturerId: json['manufacturer_id'] as int,
      isTaxable: (json['is_taxable'] as int) == 1,
      negativeAllow: (json['negative_allow'] as int?) == 1,
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
      'part_number': partNumber,
      'description': description,
      'hsn_code_id': hsnCodeId,
      'uqc_id': uqcId,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      if (mrp != null) 'mrp': mrp,
      'sub_category_id': subCategoryId,
      'manufacturer_id': manufacturerId,
      'is_taxable': isTaxable ? 1 : 0,
      'negative_allow': negativeAllow ? 1 : 0,
      'is_enabled': isEnabled ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  Product copyWith({
    int? id,
    String? name,
    String? partNumber,
    String? description,
    int? hsnCodeId,
    int? uqcId,
    double? costPrice,
    double? sellingPrice,
    double? mrp,
    int? subCategoryId,
    int? manufacturerId,
    bool? isTaxable,
    bool? negativeAllow,
    bool? isEnabled,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      partNumber: partNumber ?? this.partNumber,
      description: description ?? this.description,
      hsnCodeId: hsnCodeId ?? this.hsnCodeId,
      uqcId: uqcId ?? this.uqcId,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      mrp: mrp ?? this.mrp,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      isTaxable: isTaxable ?? this.isTaxable,
      negativeAllow: negativeAllow ?? this.negativeAllow,
      isEnabled: isEnabled ?? this.isEnabled,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProductImage {
  final int? id;
  final int productId;
  final String imagePath;
  final bool isPrimary;
  final bool isDeleted;

  ProductImage({
    this.id,
    required this.productId,
    required this.imagePath,
    this.isPrimary = false,
    this.isDeleted = false,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] as int?,
      productId: json['product_id'] as int,
      imagePath: json['image_path'] as String,
      isPrimary: (json['is_primary'] as int) == 1,
      isDeleted: (json['is_deleted'] as int) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'image_path': imagePath,
      'is_primary': isPrimary ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
}

class HsnCode {
  final int? id;
  final String code;
  final String? description;

  HsnCode({this.id, required this.code, this.description});

  factory HsnCode.fromJson(Map<String, dynamic> json) {
    return HsnCode(
      id: json['id'] as int?,
      code: json['code'] as String,
      description: json['description'] as String?,
    );
  }
}

class Uqc {
  final int? id;
  final String code;
  final String? description;

  Uqc({this.id, required this.code, this.description});

  factory Uqc.fromJson(Map<String, dynamic> json) {
    return Uqc(
      id: json['id'] as int?,
      code: json['code'] as String,
      description: json['description'] as String?,
    );
  }
}
