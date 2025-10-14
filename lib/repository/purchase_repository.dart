import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../model/purchase.dart';

class PurchaseRepository {
  final Database _db;

  PurchaseRepository(this._db);

  // Generate next purchase number in format: DDMMYYSSSSSS
  // Example: 20122500001 for 20 Dec 2025, first purchase
  // Maximum 99999 purchases per day (00001 to 99999)
  Future<String> generatePurchaseNumber() async {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString().substring(2); // Last 2 digits of year
    final datePrefix = '$day$month$year'; // DDMMYY

    // Get the last purchase number for today
    final result = await _db.rawQuery(
      '''SELECT purchase_number FROM purchases
         WHERE purchase_number LIKE ?
         AND is_deleted = 0
         ORDER BY purchase_number DESC LIMIT 1''',
      ['$datePrefix%'],
    );

    int sequenceNumber = 1;

    if (result.isNotEmpty) {
      final lastNumber = result.first['purchase_number'] as String;
      // Extract the last 5 digits (sequence number)
      final lastSequence = int.parse(lastNumber.substring(6));

      // Check if we've reached the daily limit
      if (lastSequence >= 99999) {
        throw Exception(
          'Daily purchase limit reached (99,999). Please come back tomorrow to create more purchases.',
        );
      }

      sequenceNumber = lastSequence + 1;
    }

    // Format: DDMMYYSSSSSS (6 digits date + 5 digits sequence)
    return '$datePrefix${sequenceNumber.toString().padLeft(5, '0')}';
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
      '''SELECT p.*,
         v.name as vendor_name,
         v.legal_name as vendor_legal_name,
         v.gst_number as vendor_gst,
         v.phone as vendor_phone,
         v.email as vendor_email,
         v.address_line1 as vendor_address_line1,
         v.address_line2 as vendor_address_line2,
         v.city as vendor_city,
         v.state as vendor_state,
         v.pincode as vendor_pincode
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

  // Generate auto-purchase number in format: AUTO-DDMMYYXXXXX
  // Example: AUTO-20122500001 for 20 Dec 2025, first auto-purchase
  // Maximum 99999 auto-purchases per day (00001 to 99999)
  Future<String> generateAutoPurchaseNumber(Transaction txn) async {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString().substring(2); // Last 2 digits of year
    final datePrefix = 'AUTO-$day$month$year'; // AUTO-DDMMYY

    // Get the last auto-purchase number for today
    final result = await txn.rawQuery(
      '''SELECT purchase_number FROM purchases
         WHERE purchase_number LIKE ?
         AND is_deleted = 0
         ORDER BY purchase_number DESC LIMIT 1''',
      ['$datePrefix%'],
    );

    int sequenceNumber = 1;

    if (result.isNotEmpty) {
      final lastNumber = result.first['purchase_number'] as String;
      // Extract the last 5 digits (sequence number)
      // Format: AUTO-DDMMYYXXXXX (total 16 chars, last 5 are sequence)
      if (lastNumber.length >= 16) {
        final lastSequence = int.tryParse(lastNumber.substring(11)) ?? 0;

        // Check if we've reached the daily limit
        if (lastSequence >= 99999) {
          throw Exception(
            'Daily auto-purchase limit reached (99,999). Please come back tomorrow.',
          );
        }

        sequenceNumber = lastSequence + 1;
      }
    }

    // Format: AUTO-DDMMYYXXXXX (4 chars prefix + 6 chars date + 5 digits sequence)
    return '$datePrefix${sequenceNumber.toString().padLeft(5, '0')}';
  }

  // Create automatic purchase for insufficient stock (called from bill creation)
  // This is called within a transaction context
  Future<int> createAutoPurchaseInTransaction(
    Transaction txn,
    int productId,
    String productName,
    String? partNumber,
    String? hsnCode,
    String? uqcCode,
    double costPrice,
    int quantity,
    int sourceBillId,
  ) async {
    final now = DateTime.now();
    final purchaseNumber = await generateAutoPurchaseNumber(txn);

    // Auto-stock vendor ID is 7
    const autoStockVendorId = 7;

    // For auto-purchases, we keep it simple: no tax breakdown
    final subtotal = costPrice * quantity;
    final totalAmount = subtotal;

    // Insert purchase
    final purchaseId = await txn.rawInsert(
      '''INSERT INTO purchases
      (purchase_number, purchase_reference_number, purchase_reference_date,
      vendor_id, subtotal, tax_amount, total_amount, is_auto_purchase, source_bill_id,
      created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)''',
      [
        purchaseNumber,
        null, // No reference number
        null, // No reference date
        autoStockVendorId,
        subtotal,
        0.0, // No tax for auto-purchases
        totalAmount,
        sourceBillId,
        now.toIso8601String(),
        now.toIso8601String(),
      ],
    );

    // Insert purchase item
    final purchaseItemId = await txn.rawInsert(
      '''INSERT INTO purchase_items
      (purchase_id, product_id, product_name, part_number, hsn_code, uqc_code,
      cost_price, quantity, subtotal, cgst_rate, sgst_rate, igst_rate, utgst_rate,
      cgst_amount, sgst_amount, igst_amount, utgst_amount, tax_amount, total_amount,
      created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, 0, 0, 0, 0, ?, datetime('now'), datetime('now'))''',
      [
        purchaseId,
        productId,
        productName,
        partNumber,
        hsnCode,
        uqcCode,
        costPrice,
        quantity,
        subtotal,
        totalAmount,
      ],
    );

    // Create stock batch
    final batchNumber = await _generateBatchNumber(txn, purchaseId, productId);
    await txn.rawInsert(
      '''INSERT INTO stock_batches
      (product_id, purchase_item_id, batch_number, quantity_received,
      quantity_remaining, cost_price, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
      [
        productId,
        purchaseItemId,
        batchNumber,
        quantity,
        quantity, // Initially, remaining = received
        costPrice,
      ],
    );

    return purchaseId;
  }
}
