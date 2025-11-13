import 'package:sqflite/sqflite.dart';
import '../model/key_value.dart';

class KeyValueRepository {
  final Database _db;

  KeyValueRepository(this._db);

  // Get value by key
  Future<String?> getValue(String key) async {
    final result = await _db.rawQuery(
      'SELECT value FROM key_values WHERE key = ?',
      [key],
    );

    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  // Get KeyValue object by key
  Future<KeyValue?> getKeyValue(String key) async {
    final result = await _db.rawQuery(
      'SELECT * FROM key_values WHERE key = ?',
      [key],
    );

    if (result.isEmpty) return null;
    return KeyValue.fromJson(result.first);
  }

  // Set or update value for a key
  Future<void> setValue(String key, String value) async {
    // Check if key exists
    final existing = await getValue(key);

    if (existing == null) {
      // Insert new key-value pair
      await _db.rawInsert('INSERT INTO key_values (key, value) VALUES (?, ?)', [
        key,
        value,
      ]);
    } else {
      // Update existing key-value pair
      await _db.rawUpdate(
        'UPDATE key_values SET value = ?, updated_at = CURRENT_TIMESTAMP WHERE key = ?',
        [value, key],
      );
    }
  }

  // Delete a key-value pair
  Future<void> deleteKey(String key) async {
    await _db.rawDelete('DELETE FROM key_values WHERE key = ?', [key]);
  }

  // Get all key-value pairs
  Future<List<KeyValue>> getAllKeyValues() async {
    final result = await _db.rawQuery('SELECT * FROM key_values');
    return result.map((row) => KeyValue.fromJson(row)).toList();
  }

  // Check if key exists
  Future<bool> hasKey(String key) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM key_values WHERE key = ?',
      [key],
    );

    final count = result.first['count'] as int;
    return count > 0;
  }
}
