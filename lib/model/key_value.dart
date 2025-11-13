class KeyValue {
  final String key;
  final String value;
  final String? createdAt;
  final String? updatedAt;

  KeyValue({
    required this.key,
    required this.value,
    this.createdAt,
    this.updatedAt,
  });

  // From JSON (database row)
  factory KeyValue.fromJson(Map<String, dynamic> json) {
    return KeyValue(
      key: json['key'] as String,
      value: json['value'] as String,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  // To JSON (for database insert/update)
  Map<String, dynamic> toJson() {
    return {'key': key, 'value': value};
  }

  // Copy with
  KeyValue copyWith({
    String? key,
    String? value,
    String? createdAt,
    String? updatedAt,
  }) {
    return KeyValue(
      key: key ?? this.key,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
