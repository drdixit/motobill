class GstRate {
  final int? id;
  final int hsnCodeId;
  final double cgst;
  final double sgst;
  final double igst;
  final double utgst;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final bool isEnabled;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GstRate({
    this.id,
    required this.hsnCodeId,
    required this.cgst,
    required this.sgst,
    required this.igst,
    this.utgst = 0.0,
    required this.effectiveFrom,
    this.effectiveTo,
    this.isEnabled = true,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory GstRate.fromJson(Map<String, dynamic> json) {
    return GstRate(
      id: json['id'] as int?,
      hsnCodeId: json['hsn_code_id'] as int,
      cgst: (json['cgst'] as num).toDouble(),
      sgst: (json['sgst'] as num).toDouble(),
      igst: (json['igst'] as num).toDouble(),
      utgst: (json['utgst'] as num).toDouble(),
      effectiveFrom: DateTime.parse(json['effective_from'] as String),
      effectiveTo: json['effective_to'] != null
          ? DateTime.parse(json['effective_to'] as String)
          : null,
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
      'hsn_code_id': hsnCodeId,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'utgst': utgst,
      'effective_from': effectiveFrom.toIso8601String().split('T')[0],
      if (effectiveTo != null)
        'effective_to': effectiveTo!.toIso8601String().split('T')[0],
      'is_enabled': isEnabled ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  GstRate copyWith({
    int? id,
    int? hsnCodeId,
    double? cgst,
    double? sgst,
    double? igst,
    double? utgst,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    bool? isEnabled,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GstRate(
      id: id ?? this.id,
      hsnCodeId: hsnCodeId ?? this.hsnCodeId,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
      igst: igst ?? this.igst,
      utgst: utgst ?? this.utgst,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      isEnabled: isEnabled ?? this.isEnabled,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double get totalGst => cgst + sgst;
}
