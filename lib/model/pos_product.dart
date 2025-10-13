class PosProduct {
  final int id;
  final String name;
  final String? partNumber;
  final double sellingPrice;
  final double costPrice;
  final String? imagePath;
  final String? hsnCode;
  final String? uqcCode;
  final String subCategoryName;
  final String mainCategoryName;
  final String manufacturerName;
  final bool isTaxable;
  final int hsnCodeId;
  final int uqcId;
  final int subCategoryId;
  final int manufacturerId;

  PosProduct({
    required this.id,
    required this.name,
    this.partNumber,
    required this.sellingPrice,
    required this.costPrice,
    this.imagePath,
    this.hsnCode,
    this.uqcCode,
    required this.subCategoryName,
    required this.mainCategoryName,
    required this.manufacturerName,
    required this.isTaxable,
    required this.hsnCodeId,
    required this.uqcId,
    required this.subCategoryId,
    required this.manufacturerId,
  });

  factory PosProduct.fromJson(Map<String, dynamic> json) {
    return PosProduct(
      id: json['id'] as int,
      name: json['name'] as String,
      partNumber: json['part_number'] as String?,
      sellingPrice: (json['selling_price'] as num).toDouble(),
      costPrice: (json['cost_price'] as num).toDouble(),
      imagePath: json['image_path'] as String?,
      hsnCode: json['hsn_code'] as String?,
      uqcCode: json['uqc_code'] as String?,
      subCategoryName: json['sub_category_name'] as String,
      mainCategoryName: json['main_category_name'] as String,
      manufacturerName: json['manufacturer_name'] as String,
      isTaxable: (json['is_taxable'] as int) == 1,
      hsnCodeId: json['hsn_code_id'] as int,
      uqcId: json['uqc_id'] as int,
      subCategoryId: json['sub_category_id'] as int,
      manufacturerId: json['manufacturer_id'] as int,
    );
  }
}
