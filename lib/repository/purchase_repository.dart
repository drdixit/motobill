import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../model/purchase.dart';

class PurchaseRepository {
  final Database _db;

  PurchaseRepository(this._db);

  // Generate next purchase number
  Future<String> generatePurchaseNumber() async {
    final result = await _db.rawQuery(
      'SELECT purchase_number FROM purchases WHERE is_deleted = 0 ORDER BY id DESC LIMIT 1',
    );

    if (result.isEmpty) {
      return 'PUR-0001';
    }

    final lastNumber = result.first['purchase_number'] as String;
    final numPart = int.parse(lastNumber.split('-').last);
    final newNum = numPart + 1;
    return 'PUR-${newNum.toString().padLeft(4, '0')}';
  }

  // Create purchase with items (transaction)
  Future<int> createPurchase(
    Purchase purchase,
    List<PurchaseItem> items,
  ) async {
    return await _db.transaction((txn) async {
      // Insert purchase
      final purchaseId = await txn.rawInsert(
        '''INSERT INTO purchases
        (purchase_number, purchase_reference_number, purchase_reference_date,
        vendor_id, subtotal, tax_amount, total_amount, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          purchase.purchaseNumber,
          purchase.purchaseReferenceNumber,
          purchase.purchaseReferenceDate?.toIso8601String().split('T')[0],
          purchase.vendorId,
          purchase.subtotal,
          purchase.taxAmount,
          purchase.totalAmount,
          purchase.createdAt.toIso8601String(),
          purchase.updatedAt.toIso8601String(),
        ],
      );

      // Insert purchase items and create stock batches
      for (final item in items) {
        final purchaseItemId = await txn.rawInsert(
          '''INSERT INTO purchase_items
          (purchase_id, product_id, product_name, part_number, hsn_code, uqc_code,
          cost_price, quantity, subtotal, cgst_rate, sgst_rate, igst_rate, utgst_rate,
          cgst_amount, sgst_amount, igst_amount, utgst_amount, tax_amount, total_amount,
          created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
          [
            purchaseId,
            item.productId,
            item.productName,
            item.partNumber,
            item.hsnCode,
            item.uqcCode,
            item.costPrice,
            item.quantity,
            item.subtotal,
            item.cgstRate,
            item.sgstRate,
            item.igstRate,
            item.utgstRate,
            item.cgstAmount,
            item.sgstAmount,
            item.igstAmount,
            item.utgstAmount,
            item.taxAmount,
            item.totalAmount,
          ],
        );

        // Create stock batch
        final batchNumber = await _generateBatchNumber(
          txn,
          purchaseId,
          item.productId,
        );
        await txn.rawInsert(
          '''INSERT INTO stock_batches
          (product_id, purchase_item_id, batch_number, quantity_received,
          quantity_remaining, cost_price, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
          [
            item.productId,
            purchaseItemId,
            batchNumber,
            item.quantity,
            item.quantity, // Initially, remaining = received
            item.costPrice,
          ],
        );
      }

      return purchaseId;
    });
  }

  // Generate batch number
  Future<String> _generateBatchNumber(
    Transaction txn,
    int purchaseId,
    int productId,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'BATCH-$purchaseId-$productId-$timestamp';
  }

  // Get all purchases
  Future<List<Map<String, dynamic>>> getAllPurchases() async {
    return await _db.rawQuery(
      '''SELECT p.*, v.name as vendor_name, v.gst_number as vendor_gst
      FROM purchases p
      LEFT JOIN vendors v ON p.vendor_id = v.id
      WHERE p.is_deleted = 0
      ORDER BY p.id DESC''',
    );
  }

  // Get purchase by id
  Future<Map<String, dynamic>?> getPurchaseById(int id) async {
    final result = await _db.rawQuery(
      '''SELECT p.*, v.name as vendor_name, v.gst_number as vendor_gst
      FROM purchases p
      LEFT JOIN vendors v ON p.vendor_id = v.id
      WHERE p.id = ? AND p.is_deleted = 0''',
      [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Get purchase items
  Future<List<Map<String, dynamic>>> getPurchaseItems(int purchaseId) async {
    return await _db.rawQuery(
      'SELECT * FROM purchase_items WHERE purchase_id = ? AND is_deleted = 0',
      [purchaseId],
    );
  }

  // Delete purchase (soft delete)
  Future<void> deletePurchase(int id) async {
    await _db.rawUpdate(
      'UPDATE purchases SET is_deleted = 1, updated_at = datetime(\'now\') WHERE id = ?',
      [id],
    );
  }
}
