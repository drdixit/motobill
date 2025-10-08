class HsnCode {
  final int? id;
  final String code;
  final String? description;
  final bool isEnabled;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  HsnCode({
    this.id,
    required this.code,
    this.description,
    this.isEnabled = true,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory HsnCode.fromJson(Map<String, dynamic> json) {
    return HsnCode(
      id: json['id'] as int?,
      code: json['code'] as String,
      description: json['description'] as String?,
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
      'code': code,
      'description': description,
      'is_enabled': isEnabled ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  HsnCode copyWith({
    int? id,
    String? code,
    String? description,
    bool? isEnabled,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HsnCode(
      id: id ?? this.id,
      code: code ?? this.code,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
