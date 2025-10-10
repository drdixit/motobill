class Bill {
  final int? id;
  final String billNumber;
  final int customerId;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Bill({
    this.id,
    required this.billNumber,
    required this.customerId,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] as int?,
      billNumber: json['bill_number'] as String,
      customerId: json['customer_id'] as int,
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
      'bill_number': billNumber,
      'customer_id': customerId,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class BillItem {
  final int? id;
  final int? billId;
  final int productId;
  final String productName;
  final String? partNumber;
  final String? hsnCode;
  final String? uqcCode;
  final double costPrice;
  final double sellingPrice;
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

  BillItem({
    this.id,
    this.billId,
    required this.productId,
    required this.productName,
    this.partNumber,
    this.hsnCode,
    this.uqcCode,
    required this.costPrice,
    required this.sellingPrice,
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
      if (billId != null) 'bill_id': billId,
      'product_id': productId,
      'product_name': productName,
      'part_number': partNumber,
      'hsn_code': hsnCode,
      'uqc_code': uqcCode,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
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

  BillItem copyWith({
    int? productId,
    String? productName,
    String? partNumber,
    String? hsnCode,
    String? uqcCode,
    double? costPrice,
    double? sellingPrice,
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
    return BillItem(
      id: id,
      billId: billId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      partNumber: partNumber ?? this.partNumber,
      hsnCode: hsnCode ?? this.hsnCode,
      uqcCode: uqcCode ?? this.uqcCode,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
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
