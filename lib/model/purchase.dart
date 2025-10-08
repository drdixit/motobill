class Purchase {
  final int? id;
  final String purchaseNumber;
  final String? purchaseReferenceNumber;
  final DateTime? purchaseReferenceDate;
  final int vendorId;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Purchase({
    this.id,
    required this.purchaseNumber,
    this.purchaseReferenceNumber,
    this.purchaseReferenceDate,
    required this.vendorId,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'] as int?,
      purchaseNumber: json['purchase_number'] as String,
      purchaseReferenceNumber: json['purchase_reference_number'] as String?,
      purchaseReferenceDate: json['purchase_reference_date'] != null
          ? DateTime.parse(json['purchase_reference_date'] as String)
          : null,
      vendorId: json['vendor_id'] as int,
      subtotal: (json['subtotal'] as num).toDouble(),
      taxAmount: (json['tax_amount'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      isDeleted: (json['is_deleted'] as int) == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'purchase_number': purchaseNumber,
      'purchase_reference_number': purchaseReferenceNumber,
      'purchase_reference_date': purchaseReferenceDate?.toIso8601String().split(
        'T',
      )[0],
      'vendor_id': vendorId,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class PurchaseItem {
  final int? id;
  final int? purchaseId;
  final int productId;
  final String productName;
  final String? partNumber;
  final String? hsnCode;
  final String? uqcCode;
  final double costPrice;
  final int quantity;
  final double subtotal;
  final double cgstRate;
  final double sgstRate;
  final double igstRate;
  final double utgstRate;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double utgstAmount;
  final double taxAmount;
  final double totalAmount;

  PurchaseItem({
    this.id,
    this.purchaseId,
    required this.productId,
    required this.productName,
    this.partNumber,
    this.hsnCode,
    this.uqcCode,
    required this.costPrice,
    required this.quantity,
    required this.subtotal,
    this.cgstRate = 0,
    this.sgstRate = 0,
    this.igstRate = 0,
    this.utgstRate = 0,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.utgstAmount,
    required this.taxAmount,
    required this.totalAmount,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (purchaseId != null) 'purchase_id': purchaseId,
      'product_id': productId,
      'product_name': productName,
      'part_number': partNumber,
      'hsn_code': hsnCode,
      'uqc_code': uqcCode,
      'cost_price': costPrice,
      'quantity': quantity,
      'subtotal': subtotal,
      'cgst_rate': cgstRate,
      'sgst_rate': sgstRate,
      'igst_rate': igstRate,
      'utgst_rate': utgstRate,
      'cgst_amount': cgstAmount,
      'sgst_amount': sgstAmount,
      'igst_amount': igstAmount,
      'utgst_amount': utgstAmount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
    };
  }

  PurchaseItem copyWith({
    int? productId,
    String? productName,
    String? partNumber,
    String? hsnCode,
    String? uqcCode,
    double? costPrice,
    int? quantity,
    double? subtotal,
    double? cgstRate,
    double? sgstRate,
    double? igstRate,
    double? utgstRate,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    double? utgstAmount,
    double? taxAmount,
    double? totalAmount,
  }) {
    return PurchaseItem(
      id: id,
      purchaseId: purchaseId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      partNumber: partNumber ?? this.partNumber,
      hsnCode: hsnCode ?? this.hsnCode,
      uqcCode: uqcCode ?? this.uqcCode,
      costPrice: costPrice ?? this.costPrice,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
      cgstRate: cgstRate ?? this.cgstRate,
      sgstRate: sgstRate ?? this.sgstRate,
      igstRate: igstRate ?? this.igstRate,
      utgstRate: utgstRate ?? this.utgstRate,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      utgstAmount: utgstAmount ?? this.utgstAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}
