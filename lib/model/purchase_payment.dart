class PurchasePayment {
  final int? id;
  final int purchaseId;
  final double amount;
  final String
  paymentMethod; // 'cash', 'upi', 'card', 'bank_transfer', 'cheque'
  final DateTime paymentDate;
  final String? notes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  PurchasePayment({
    this.id,
    required this.purchaseId,
    required this.amount,
    this.paymentMethod = 'cash',
    required this.paymentDate,
    this.notes,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PurchasePayment.fromJson(Map<String, dynamic> json) {
    return PurchasePayment(
      id: json['id'] as int?,
      purchaseId: json['purchase_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      paymentDate: DateTime.parse(json['payment_date'] as String),
      notes: json['notes'] as String?,
      isDeleted: (json['is_deleted'] as int) == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'purchase_id': purchaseId,
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_date': paymentDate.toIso8601String(),
      'notes': notes,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PurchasePayment copyWith({
    int? id,
    int? purchaseId,
    double? amount,
    String? paymentMethod,
    DateTime? paymentDate,
    String? notes,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchasePayment(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentDate: paymentDate ?? this.paymentDate,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
