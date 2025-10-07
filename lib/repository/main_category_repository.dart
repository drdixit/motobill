import 'package:sqflite_common/sqlite_api.dart';
import '../model/main_category.dart';

class MainCategoryRepository {
  final Database _db;

  MainCategoryRepository(this._db);

  Future<List<MainCategory>> getAllMainCategories() async {
    final result = await _db.rawQuery(
      'SELECT * FROM main_categories WHERE is_deleted = 0 ORDER BY name ASC',
    );
    return result.map((json) => MainCategory.fromJson(json)).toList();
  }

  Future<MainCategory?> getMainCategoryById(int id) async {
    final result = await _db.rawQuery(
      'SELECT * FROM main_categories WHERE id = ? AND is_deleted = 0',
      [id],
    );
    if (result.isEmpty) return null;
    return MainCategory.fromJson(result.first);
  }

  Future<int> createMainCategory(MainCategory category) async {
    return await _db.rawInsert(
      '''INSERT INTO main_categories (name, description, image, is_enabled, is_deleted, created_at, updated_at)
         VALUES (?, ?, ?, ?, 0, datetime('now'), datetime('now'))''',
      [
        category.name,
        category.description,
        category.image,
        category.isEnabled ? 1 : 0,
      ],
    );
  }

  Future<void> updateMainCategory(MainCategory category) async {
    await _db.rawUpdate(
      '''UPDATE main_categories SET name = ?, description = ?, image = ?,
         is_enabled = ?, updated_at = datetime('now')
         WHERE id = ?''',
      [
        category.name,
        category.description,
        category.image,
        category.isEnabled ? 1 : 0,
        category.id,
      ],
    );
  }

  Future<void> softDeleteMainCategory(int id) async {
    await _db.rawUpdate(
      'UPDATE main_categories SET is_deleted = 1, updated_at = datetime(\'now\') WHERE id = ?',
      [id],
    );
  }

  Future<void> toggleMainCategoryEnabled(int id, bool isEnabled) async {
    await _db.rawUpdate(
      'UPDATE main_categories SET is_enabled = ?, updated_at = datetime(\'now\') WHERE id = ?',
      [isEnabled ? 1 : 0, id],
    );
  }

  Future<List<MainCategory>> searchMainCategories(String query) async {
    final result = await _db.rawQuery(
      '''SELECT * FROM main_categories
         WHERE is_deleted = 0
         AND (name LIKE ? OR description LIKE ?)
         ORDER BY name ASC''',
      ['%$query%', '%$query%'],
    );
    return result.map((json) => MainCategory.fromJson(json)).toList();
  }
}
