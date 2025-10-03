import 'package:sqflite/sqflite.dart';
import '../model/todo.dart';

class TodoRepository {
  final Database _db;

  TodoRepository(this._db);

  // Get all todos
  Future<List<Todo>> getAllTodos() async {
    try {
      final result = await _db.rawQuery('SELECT * FROM test ORDER BY id DESC');
      return result.map((json) => Todo.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load todos: $e');
    }
  }

  // Get a single todo by id
  Future<Todo?> getTodoById(int id) async {
    try {
      final result = await _db.rawQuery('SELECT * FROM test WHERE id = ?', [
        id,
      ]);
      if (result.isEmpty) return null;
      return Todo.fromJson(result.first);
    } catch (e) {
      throw Exception('Failed to load todo: $e');
    }
  }

  // Add a new todo
  Future<int> addTodo(Todo todo) async {
    try {
      final id = await _db.rawInsert(
        'INSERT INTO test (name, description) VALUES (?, ?)',
        [todo.name, todo.description],
      );
      return id;
    } catch (e) {
      throw Exception('Failed to add todo: $e');
    }
  }

  // Update an existing todo
  Future<void> updateTodo(Todo todo) async {
    try {
      await _db.rawUpdate(
        'UPDATE test SET name = ?, description = ? WHERE id = ?',
        [todo.name, todo.description, todo.id],
      );
    } catch (e) {
      throw Exception('Failed to update todo: $e');
    }
  }

  // Delete a todo
  Future<void> deleteTodo(int id) async {
    try {
      await _db.rawDelete('DELETE FROM test WHERE id = ?', [id]);
    } catch (e) {
      throw Exception('Failed to delete todo: $e');
    }
  }
}
