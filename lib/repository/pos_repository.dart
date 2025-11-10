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
          p.description,
          p.selling_price,
          p.cost_price,
          p.is_taxable,
          p.negative_allow,
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
          g.igst as igst_rate,
          g.utgst as utgst_rate,
          COALESCE(SUM(sb.quantity_remaining), 0) as stock,
          COALESCE(SUM(CASE WHEN sb.is_taxable = 1 THEN sb.quantity_remaining ELSE 0 END), 0) as taxable_stock,
          COALESCE(SUM(CASE WHEN sb.is_taxable = 0 THEN sb.quantity_remaining ELSE 0 END), 0) as non_taxable_stock
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
        LEFT JOIN stock_batches sb ON p.id = sb.product_id AND sb.is_deleted = 0
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
          ' AND (p.name LIKE ? OR p.part_number LIKE ? OR p.description LIKE ? OR m.name LIKE ?)',
        );
        final searchTerm = '%$searchQuery%';
        args.addAll([searchTerm, searchTerm, searchTerm, searchTerm]);
      }

      query.write(' GROUP BY p.id');
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

  /// Get last custom price (per unit with tax) for a product sold to a customer
  /// Returns null if no previous sale found or if default price was used
  Future<double?> getLastCustomPrice(int customerId, int productId) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT bi.total_amount, bi.quantity
        FROM bill_items bi
        INNER JOIN bills b ON bi.bill_id = b.id
        WHERE b.customer_id = ?
          AND bi.product_id = ?
          AND b.is_deleted = 0
          AND bi.is_deleted = 0
        ORDER BY b.created_at DESC
        LIMIT 1
      ''',
        [customerId, productId],
      );

      if (result.isEmpty) return null;

      final totalAmount = result.first['total_amount'] as double;
      final quantity = result.first['quantity'] as int;

      if (quantity == 0) return null;

      // Calculate per unit price with tax
      return totalAmount / quantity;
    } catch (e) {
      throw Exception('Failed to get last custom price: $e');
    }
  }

  /// Get last custom prices for multiple products sold to a customer
  /// Returns a map of productId -> lastCustomPrice (per unit with tax)
  Future<Map<int, double>> getLastCustomPrices(
    int customerId,
    List<int> productIds,
  ) async {
    try {
      if (productIds.isEmpty) return {};

      final placeholders = List.filled(productIds.length, '?').join(',');

      final result = await _db.rawQuery(
        '''
        SELECT
          bi.product_id,
          bi.total_amount,
          bi.quantity,
          b.created_at
        FROM bill_items bi
        INNER JOIN bills b ON bi.bill_id = b.id
        WHERE b.customer_id = ?
          AND bi.product_id IN ($placeholders)
          AND b.is_deleted = 0
          AND bi.is_deleted = 0
        ORDER BY b.created_at DESC
      ''',
        [customerId, ...productIds],
      );

      final Map<int, double> prices = {};
      final Set<int> processedProducts = {};

      for (final row in result) {
        final productId = row['product_id'] as int;

        // Only take the first (most recent) price for each product
        if (!processedProducts.contains(productId)) {
          final totalAmount = row['total_amount'] as double;
          final quantity = row['quantity'] as int;

          if (quantity > 0) {
            prices[productId] = totalAmount / quantity;
          }

          processedProducts.add(productId);
        }
      }

      return prices;
    } catch (e) {
      throw Exception('Failed to get last custom prices: $e');
    }
  }
}
