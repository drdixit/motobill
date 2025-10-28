class Bank {
  final int? id;
  final String accountHolderName;
  final String accountNumber;
  final String? ifscCode;
  final String? bankName;
  final String? branchName;
  final int? customerId;
  final int? vendorId;
  final int? companyId;
  final bool isEnabled;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Bank({
    this.id,
    required this.accountHolderName,
    required this.accountNumber,
    this.ifscCode,
    this.bankName,
    this.branchName,
    this.customerId,
    this.vendorId,
    this.companyId,
    this.isEnabled = true,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Bank.fromJson(Map<String, dynamic> json) {
    return Bank(
      id: json['id'] as int?,
      accountHolderName: json['account_holder_name'] as String,
      accountNumber: json['account_number'] as String,
      ifscCode: json['ifsc_code'] as String?,
      bankName: json['bank_name'] as String?,
      branchName: json['branch_name'] as String?,
      customerId: json['customer_id'] as int?,
      vendorId: json['vendor_id'] as int?,
      companyId: json['company_id'] as int?,
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
      'account_holder_name': accountHolderName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'bank_name': bankName,
      'branch_name': branchName,
      'customer_id': customerId,
      'vendor_id': vendorId,
      'company_id': companyId,
      'is_enabled': isEnabled ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
}
