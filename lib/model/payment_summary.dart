class PaymentSummary {
  final int id;
  final String name;
  final String? phone;
  final String type; // 'customer' or 'vendor'
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final int billCount;

  PaymentSummary({
    required this.id,
    required this.name,
    this.phone,
    required this.type,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.billCount,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      type: json['type'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num).toDouble(),
      remainingAmount: (json['remaining_amount'] as num).toDouble(),
      billCount: json['bill_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'type': type,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'bill_count': billCount,
    };
  }
}
