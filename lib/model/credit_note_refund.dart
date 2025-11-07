class CreditNoteRefund {
  final int? id;
  final int creditNoteId;
  final double amount;
  final String refundMethod; // 'cash', 'upi', 'card', 'bank_transfer', 'cheque'
  final DateTime refundDate;
  final String? notes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  CreditNoteRefund({
    this.id,
    required this.creditNoteId,
    required this.amount,
    this.refundMethod = 'cash',
    required this.refundDate,
    this.notes,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CreditNoteRefund.fromJson(Map<String, dynamic> json) {
    return CreditNoteRefund(
      id: json['id'] as int?,
      creditNoteId: json['credit_note_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      refundMethod: json['refund_method'] as String? ?? 'cash',
      refundDate: DateTime.parse(json['refund_date'] as String),
      notes: json['notes'] as String?,
      isDeleted: (json['is_deleted'] as int) == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'credit_note_id': creditNoteId,
      'amount': amount,
      'refund_method': refundMethod,
      'refund_date': refundDate.toIso8601String(),
      'notes': notes,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
