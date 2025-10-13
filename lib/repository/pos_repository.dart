import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../model/pos_product.dart';
import '../model/main_category.dart';
import '../model/sub_category.dart';
import '../model/manufacturer.dart';

class PosRepository {
  final Database _db;

  PosRepository(this._db);

  Future<List<PosProduct>> getProductsForPos({
    int? mainCategoryId,
    int? subCategoryId,
    int? manufacturerId,
    String? searchQuery,
  }) async {
    try {
      final StringBuffer query = StringBuffer('''
        SELECT
          p.id,
          p.name,
          p.part_number,
          p.selling_price,
          p.cost_price,
          p.is_taxable,
          p.hsn_code_id,
          p.uqc_id,
          p.sub_category_id,
          p.manufacturer_id,
          h.code as hsn_code,
          u.code as uqc_code,
          sc.name as sub_category_name,
          mc.name as main_category_name,
          m.name as manufacturer_name,
          pi.image_path,
          g.cgst as cgst_rate,
          g.sgst as sgst_rate,
          g.igst as igst_rate
        FROM products p
        LEFT JOIN hsn_codes h ON p.hsn_code_id = h.id
        LEFT JOIN uqcs u ON p.uqc_id = u.id
        LEFT JOIN sub_categories sc ON p.sub_category_id = sc.id
        LEFT JOIN main_categories mc ON sc.main_category_id = mc.id
        LEFT JOIN manufacturers m ON p.manufacturer_id = m.id
        LEFT JOIN (
          SELECT product_id, image_path
          FROM product_images
          WHERE is_primary = 1 AND is_deleted = 0
        ) pi ON p.id = pi.product_id
        LEFT JOIN gst_rates g ON p.hsn_code_id = g.hsn_code_id AND g.is_deleted = 0 AND g.is_enabled = 1
        WHERE p.is_deleted = 0 AND p.is_enabled = 1
      ''');

      final List<dynamic> args = [];

      if (mainCategoryId != null) {
        query.write(' AND mc.id = ?');
        args.add(mainCategoryId);
      }

      if (subCategoryId != null) {
        query.write(' AND sc.id = ?');
        args.add(subCategoryId);
      }

      if (manufacturerId != null) {
        query.write(' AND m.id = ?');
        args.add(manufacturerId);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query.write(
          ' AND (p.name LIKE ? OR p.part_number LIKE ? OR m.name LIKE ?)',
        );
        final searchTerm = '%$searchQuery%';
        args.addAll([searchTerm, searchTerm, searchTerm]);
      }

      query.write(' ORDER BY p.name ASC');

      final result = await _db.rawQuery(query.toString(), args);
      return result.map((json) => PosProduct.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get products for POS: $e');
    }
  }

  Future<List<MainCategory>> getAllMainCategories() async {
    try {
      final result = await _db.rawQuery('''
        SELECT * FROM main_categories
        WHERE is_deleted = 0 AND is_enabled = 1
        ORDER BY name ASC
      ''');
      return result.map((json) => MainCategory.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get main categories: $e');
    }
  }

  Future<List<SubCategory>> getSubCategoriesByMainCategory(
    int mainCategoryId,
  ) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT * FROM sub_categories
        WHERE main_category_id = ? AND is_deleted = 0 AND is_enabled = 1
        ORDER BY name ASC
      ''',
        [mainCategoryId],
      );
      return result.map((json) => SubCategory.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get sub categories: $e');
    }
  }

  Future<List<Manufacturer>> getAllManufacturers() async {
    try {
      final result = await _db.rawQuery('''
        SELECT * FROM manufacturers
        WHERE is_deleted = 0 AND is_enabled = 1
        ORDER BY name ASC
      ''');
      return result.map((json) => Manufacturer.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get manufacturers: $e');
    }
  }

  Future<String?> getCompanyGstNumber() async {
    try {
      final result = await _db.rawQuery('''
        SELECT gst_number FROM company_info
        WHERE is_primary = 1 AND is_deleted = 0 AND is_enabled = 1
        LIMIT 1
      ''');
      if (result.isNotEmpty) {
        return result.first['gst_number'] as String?;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get company GST number: $e');
    }
  }
}
