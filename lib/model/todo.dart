class Todo {
  final int? id;
  final String name;
  final String description;

  const Todo({this.id, required this.name, required this.description});

  // Create Todo from database map
  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String,
    );
  }

  // Convert Todo to database map
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'description': description};
  }

  // Create a copy with updated fields
  Todo copyWith({int? id, String? name, String? description}) {
    return Todo(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }
}
