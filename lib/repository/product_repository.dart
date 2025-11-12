import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../model/product.dart';

class ProductRepository {
  final Database _db;

  ProductRepository(this._db);

  Future<List<Product>> getAllProducts() async {
    try {
      final result = await _db.rawQuery('''
        SELECT * FROM products
        WHERE is_deleted = 0
        ORDER BY name
      ''');
      return result.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get products: $e');
    }
  }

  // Get products with pagination for better performance
  Future<List<Product>> getProductsPaginated({
    required int limit,
    required int offset,
    String? searchQuery,
  }) async {
    try {
      String query = '''
        SELECT * FROM products
        WHERE is_deleted = 0
      ''';

      final params = <dynamic>[];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query += '''
          AND (
            LOWER(name) LIKE LOWER(?) OR
            LOWER(part_number) LIKE LOWER(?) OR
            LOWER(description) LIKE LOWER(?)
          )
        ''';
        final searchPattern = '%$searchQuery%';
        params.addAll([searchPattern, searchPattern, searchPattern]);
      }

      query += '''
        ORDER BY name
        LIMIT ? OFFSET ?
      ''';
      params.addAll([limit, offset]);

      final result = await _db.rawQuery(query, params);
      return result.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get paginated products: $e');
    }
  }

  // Get total count of products (for pagination)
  Future<int> getProductsCount({String? searchQuery}) async {
    try {
      String query = '''
        SELECT COUNT(*) as count FROM products
        WHERE is_deleted = 0
      ''';

      final params = <dynamic>[];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query += '''
          AND (
            LOWER(name) LIKE LOWER(?) OR
            LOWER(part_number) LIKE LOWER(?) OR
            LOWER(description) LIKE LOWER(?)
          )
        ''';
        final searchPattern = '%$searchQuery%';
        params.addAll([searchPattern, searchPattern, searchPattern]);
      }

      final result = await _db.rawQuery(query, params);
      return result.first['count'] as int;
    } catch (e) {
      throw Exception('Failed to get products count: $e');
    }
  }

  Future<Product?> getProductById(int id) async {
    try {
      final result = await _db.rawQuery(
        'SELECT * FROM products WHERE id = ? AND is_deleted = 0',
        [id],
      );
      if (result.isEmpty) return null;
      return Product.fromJson(result.first);
    } catch (e) {
      throw Exception('Failed to get product: $e');
    }
  }

  Future<int> insertProduct(Product product) async {
    try {
      // Validate foreign keys
      await _validateSubCategory(product.subCategoryId);
      await _validateManufacturer(product.manufacturerId);
      await _validateHsnCode(product.hsnCodeId);
      await _validateUqc(product.uqcId);

      final id = await _db.rawInsert(
        '''
        INSERT INTO products (
          name, part_number, description, hsn_code_id, uqc_id,
          cost_price, selling_price, mrp, sub_category_id, manufacturer_id,
          is_taxable, negative_allow, is_enabled, min, max, is_deleted, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, 0, datetime('now'), datetime('now'))
      ''',
        [
          product.name,
          product.partNumber,
          product.description,
          product.hsnCodeId,
          product.uqcId,
          product.costPrice,
          product.sellingPrice,
          product.mrp,
          product.subCategoryId,
          product.manufacturerId,
          product.negativeAllow ? 1 : 0,
          product.isEnabled ? 1 : 0,
          product.min,
          product.max,
        ],
      );
      return id;
    } catch (e) {
      throw Exception('Failed to insert product: $e');
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      if (product.id == null) {
        throw Exception('Product ID cannot be null for update');
      }

      // Validate foreign keys
      await _validateSubCategory(product.subCategoryId);
      await _validateManufacturer(product.manufacturerId);
      await _validateHsnCode(product.hsnCodeId);
      await _validateUqc(product.uqcId);

      await _db.rawUpdate(
        '''
        UPDATE products SET
          name = ?, part_number = ?, description = ?, hsn_code_id = ?, uqc_id = ?,
          cost_price = ?, selling_price = ?, mrp = ?, sub_category_id = ?, manufacturer_id = ?,
          is_taxable = 1, negative_allow = ?, is_enabled = ?, min = ?, max = ?, updated_at = datetime('now')
        WHERE id = ?
      ''',
        [
          product.name,
          product.partNumber,
          product.description,
          product.hsnCodeId,
          product.uqcId,
          product.costPrice,
          product.sellingPrice,
          product.mrp,
          product.subCategoryId,
          product.manufacturerId,
          product.negativeAllow ? 1 : 0,
          product.isEnabled ? 1 : 0,
          product.min,
          product.max,
          product.id,
        ],
      );
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      await _db.rawUpdate(
        'UPDATE products SET is_deleted = 1, updated_at = datetime(\'now\') WHERE id = ?',
        [id],
      );
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  Future<void> toggleProductStatus(int id, bool isEnabled) async {
    try {
      await _db.rawUpdate(
        'UPDATE products SET is_enabled = ?, updated_at = datetime(\'now\') WHERE id = ?',
        [isEnabled ? 1 : 0, id],
      );
    } catch (e) {
      throw Exception('Failed to toggle product status: $e');
    }
  }

  // Product Images Methods
  Future<List<ProductImage>> getProductImages(int productId) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT * FROM product_images
        WHERE product_id = ? AND is_deleted = 0
        ORDER BY is_primary DESC, id
      ''',
        [productId],
      );
      return result.map((json) => ProductImage.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get product images: $e');
    }
  }

  Future<ProductImage?> getPrimaryImage(int productId) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT * FROM product_images
        WHERE product_id = ? AND is_primary = 1 AND is_deleted = 0
        LIMIT 1
      ''',
        [productId],
      );
      if (result.isEmpty) return null;
      return ProductImage.fromJson(result.first);
    } catch (e) {
      throw Exception('Failed to get primary image: $e');
    }
  }

  Future<int> addProductImage(ProductImage image) async {
    try {
      late int id;
      await _db.transaction((txn) async {
        // If this image should be primary, set all other images to non-primary first
        if (image.isPrimary) {
          await txn.rawUpdate(
            'UPDATE product_images SET is_primary = 0 WHERE product_id = ? AND is_deleted = 0',
            [image.productId],
          );
        }
        // Insert the new image
        id = await txn.rawInsert(
          '''
          INSERT INTO product_images (product_id, image_path, is_primary, is_deleted)
          VALUES (?, ?, ?, 0)
        ''',
          [image.productId, image.imagePath, image.isPrimary ? 1 : 0],
        );
      });
      return id;
    } catch (e) {
      throw Exception('Failed to add product image: $e');
    }
  }

  Future<void> removeProductImage(int imageId) async {
    try {
      await _db.rawUpdate(
        'UPDATE product_images SET is_deleted = 1, is_primary = 0 WHERE id = ?',
        [imageId],
      );
    } catch (e) {
      throw Exception('Failed to remove product image: $e');
    }
  }

  Future<void> setPrimaryImage(int productId, int imageId) async {
    try {
      await _db.transaction((txn) async {
        // Set all images for this product to non-primary
        await txn.rawUpdate(
          'UPDATE product_images SET is_primary = 0 WHERE product_id = ?',
          [productId],
        );
        // Set the specified image as primary
        await txn.rawUpdate(
          'UPDATE product_images SET is_primary = 1 WHERE id = ?',
          [imageId],
        );
      });
    } catch (e) {
      throw Exception('Failed to set primary image: $e');
    }
  }

  // Dropdown data methods
  Future<List<HsnCode>> getAllHsnCodes() async {
    try {
      final result = await _db.rawQuery('''
        SELECT * FROM hsn_codes
        WHERE is_deleted = 0 AND is_enabled = 1
        ORDER BY code
      ''');
      return result.map((json) => HsnCode.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get HSN codes: $e');
    }
  }

  Future<List<Uqc>> getAllUqcs() async {
    try {
      final result = await _db.rawQuery('''
        SELECT * FROM uqcs
        WHERE is_deleted = 0 AND is_enabled = 1
        ORDER BY code
      ''');
      return result.map((json) => Uqc.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get UQCs: $e');
    }
  }

  // Validation methods
  Future<void> _validateSubCategory(int subCategoryId) async {
    final result = await _db.rawQuery(
      'SELECT id FROM sub_categories WHERE id = ? AND is_deleted = 0',
      [subCategoryId],
    );
    if (result.isEmpty) {
      throw Exception('Invalid sub category ID');
    }
  }

  Future<void> _validateManufacturer(int manufacturerId) async {
    final result = await _db.rawQuery(
      'SELECT id FROM manufacturers WHERE id = ? AND is_deleted = 0',
      [manufacturerId],
    );
    if (result.isEmpty) {
      throw Exception('Invalid manufacturer ID');
    }
  }

  Future<void> _validateHsnCode(int hsnCodeId) async {
    final result = await _db.rawQuery(
      'SELECT id FROM hsn_codes WHERE id = ? AND is_deleted = 0',
      [hsnCodeId],
    );
    if (result.isEmpty) {
      throw Exception('Invalid HSN code ID');
    }
  }

  Future<void> _validateUqc(int uqcId) async {
    final result = await _db.rawQuery(
      'SELECT id FROM uqcs WHERE id = ? AND is_deleted = 0',
      [uqcId],
    );
    if (result.isEmpty) {
      throw Exception('Invalid UQC ID');
    }
  }

  /// Get product by part number (for automated purchase bill creation)
  Future<Product?> getProductByPartNumber(String partNumber) async {
    try {
      // Case-insensitive search for part number
      final result = await _db.rawQuery(
        'SELECT * FROM products WHERE LOWER(part_number) = LOWER(?) AND is_deleted = 0',
        [partNumber.trim()],
      );
      if (result.isEmpty) return null;
      return Product.fromJson(result.first);
    } catch (e) {
      throw Exception('Failed to get product by part number: $e');
    }
  }
}
