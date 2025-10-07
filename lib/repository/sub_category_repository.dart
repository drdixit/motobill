import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../model/sub_category.dart';

class SubCategoryRepository {
  final Database _db;

  SubCategoryRepository(this._db);

  Future<List<SubCategory>> getAllSubCategories() async {
    final result = await _db.rawQuery('''
      SELECT * FROM sub_categories
      WHERE is_deleted = 0
      ORDER BY name ASC
    ''');
    return result.map((json) => SubCategory.fromJson(json)).toList();
  }

  Future<SubCategory?> getSubCategoryById(int id) async {
    final result = await _db.rawQuery(
      'SELECT * FROM sub_categories WHERE id = ? AND is_deleted = 0',
      [id],
    );
    if (result.isEmpty) return null;
    return SubCategory.fromJson(result.first);
  }

  Future<int> createSubCategory(SubCategory subCategory) async {
    // Validate main_category_id exists
    final mainCategoryCheck = await _db.rawQuery(
      'SELECT id FROM main_categories WHERE id = ? AND is_deleted = 0',
      [subCategory.mainCategoryId],
    );

    if (mainCategoryCheck.isEmpty) {
      throw Exception('Invalid main category ID');
    }

    return await _db.rawInsert(
      '''INSERT INTO sub_categories
         (main_category_id, name, description, image, is_enabled)
         VALUES (?, ?, ?, ?, ?)''',
      [
        subCategory.mainCategoryId,
        subCategory.name,
        subCategory.description,
        subCategory.image,
        subCategory.isEnabled ? 1 : 0,
      ],
    );
  }

  Future<void> updateSubCategory(SubCategory subCategory) async {
    // Validate main_category_id exists
    final mainCategoryCheck = await _db.rawQuery(
      'SELECT id FROM main_categories WHERE id = ? AND is_deleted = 0',
      [subCategory.mainCategoryId],
    );

    if (mainCategoryCheck.isEmpty) {
      throw Exception('Invalid main category ID');
    }

    await _db.rawUpdate(
      '''UPDATE sub_categories
         SET main_category_id = ?, name = ?, description = ?,
             image = ?, is_enabled = ?, updated_at = datetime('now')
         WHERE id = ?''',
      [
        subCategory.mainCategoryId,
        subCategory.name,
        subCategory.description,
        subCategory.image,
        subCategory.isEnabled ? 1 : 0,
        subCategory.id,
      ],
    );
  }

  Future<void> softDeleteSubCategory(int id) async {
    await _db.rawUpdate(
      'UPDATE sub_categories SET is_deleted = 1, updated_at = datetime(\'now\') WHERE id = ?',
      [id],
    );
  }

  Future<void> toggleSubCategoryEnabled(int id, bool isEnabled) async {
    await _db.rawUpdate(
      'UPDATE sub_categories SET is_enabled = ?, updated_at = datetime(\'now\') WHERE id = ?',
      [isEnabled ? 1 : 0, id],
    );
  }

  Future<List<SubCategory>> searchSubCategories(String query) async {
    final result = await _db.rawQuery(
      '''SELECT * FROM sub_categories
         WHERE is_deleted = 0 AND (name LIKE ? OR description LIKE ?)
         ORDER BY name ASC''',
      ['%$query%', '%$query%'],
    );
    return result.map((json) => SubCategory.fromJson(json)).toList();
  }

  Future<List<SubCategory>> getSubCategoriesByMainCategory(
    int mainCategoryId,
  ) async {
    final result = await _db.rawQuery(
      '''SELECT * FROM sub_categories
         WHERE main_category_id = ? AND is_deleted = 0
         ORDER BY name ASC''',
      [mainCategoryId],
    );
    return result.map((json) => SubCategory.fromJson(json)).toList();
  }
}
