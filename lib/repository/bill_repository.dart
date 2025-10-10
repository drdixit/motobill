import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../model/bill.dart';

class BillRepository {
  final Database _db;

  BillRepository(this._db);

  // Generate next bill number in format: DDMMYYSSSSSS
  // Example: 20122500001 for 20 Dec 2025, first bill
  // Maximum 99999 bills per day (00001 to 99999)
  Future<String> generateBillNumber() async {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString().substring(2); // Last 2 digits of year
    final datePrefix = '$day$month$year'; // DDMMYY

    // Get the last bill number for today
    final result = await _db.rawQuery(
      '''SELECT bill_number FROM bills
         WHERE bill_number LIKE ?
         AND is_deleted = 0
         ORDER BY bill_number DESC LIMIT 1''',
      ['$datePrefix%'],
    );

    int sequenceNumber = 1;

    if (result.isNotEmpty) {
      final lastNumber = result.first['bill_number'] as String;
      // Extract the last 5 digits (sequence number)
      final lastSequence = int.parse(lastNumber.substring(6));

      // Check if we've reached the daily limit
      if (lastSequence >= 99999) {
        throw Exception(
          'Daily bill limit reached (99,999). Please come back tomorrow to create more bills.',
        );
      }

      sequenceNumber = lastSequence + 1;
    }

    // Format: DDMMYYSSSSSS (6 digits date + 5 digits sequence)
    return '$datePrefix${sequenceNumber.toString().padLeft(5, '0')}';
  }

  // Create bill with items (transaction)
  Future<int> createBill(Bill bill, List<BillItem> items) async {
    return await _db.transaction((txn) async {
      // Insert bill
      final billId = await txn.rawInsert(
        '''INSERT INTO bills
        (bill_number, customer_id, subtotal, tax_amount, total_amount, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [
          bill.billNumber,
          bill.customerId,
          bill.subtotal,
          bill.taxAmount,
          bill.totalAmount,
          bill.createdAt.toIso8601String(),
          bill.updatedAt.toIso8601String(),
        ],
      );

      // Insert bill items and update stock
      for (final item in items) {
        // Insert bill item
        final billItemId = await txn.rawInsert(
          '''INSERT INTO bill_items
          (bill_id, product_id, product_name, part_number, hsn_code, uqc_code,
          cost_price, selling_price, quantity, subtotal, cgst_rate, sgst_rate, igst_rate, utgst_rate,
          cgst_amount, sgst_amount, igst_amount, utgst_amount, tax_amount, total_amount,
          created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
          [
            billId,
            item.productId,
            item.productName,
            item.partNumber,
            item.hsnCode,
            item.uqcCode,
            item.costPrice,
            item.sellingPrice,
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

        // Deduct stock using FIFO (First In, First Out)
        await _deductStock(txn, item.productId, item.quantity, billItemId);
      }

      return billId;
    });
  }

  // Deduct stock using FIFO method
  Future<void> _deductStock(
    Transaction txn,
    int productId,
    int quantity,
    int billItemId,
  ) async {
    int remainingQty = quantity;

    // Get available batches ordered by oldest first (FIFO)
    final batches = await txn.rawQuery(
      '''SELECT id, quantity_remaining, cost_price
      FROM stock_batches
      WHERE product_id = ? AND quantity_remaining > 0 AND is_deleted = 0
      ORDER BY created_at ASC''',
      [productId],
    );

    if (batches.isEmpty) {
      throw Exception('Insufficient stock for product ID: $productId');
    }

    int totalAvailable = 0;
    for (final batch in batches) {
      totalAvailable += batch['quantity_remaining'] as int;
    }

    if (totalAvailable < quantity) {
      throw Exception(
        'Insufficient stock for product ID: $productId. Required: $quantity, Available: $totalAvailable',
      );
    }

    // Deduct from batches using FIFO
    for (final batch in batches) {
      if (remainingQty <= 0) break;

      final stockBatchId = batch['id'] as int;
      final qtyRemaining = batch['quantity_remaining'] as int;
      final costPrice = (batch['cost_price'] as num).toDouble();

      final qtyToDeduct = remainingQty > qtyRemaining
          ? qtyRemaining
          : remainingQty;

      // Update batch quantity
      await txn.rawUpdate(
        '''UPDATE stock_batches
        SET quantity_remaining = quantity_remaining - ?,
        updated_at = datetime('now')
        WHERE id = ?''',
        [qtyToDeduct, stockBatchId],
      );

      // Record batch usage
      await txn.rawInsert(
        '''INSERT INTO stock_batch_usage
        (bill_item_id, stock_batch_id, quantity_used, cost_price, created_at)
        VALUES (?, ?, ?, ?, datetime('now'))''',
        [billItemId, stockBatchId, qtyToDeduct, costPrice],
      );

      remainingQty -= qtyToDeduct;
    }
  }

  // Get all bills
  Future<List<Map<String, dynamic>>> getAllBills() async {
    return await _db.rawQuery(
      '''SELECT b.*, c.name as customer_name, c.gst_number as customer_gst
      FROM bills b
      LEFT JOIN customers c ON b.customer_id = c.id
      WHERE b.is_deleted = 0
      ORDER BY b.id DESC''',
    );
  }

  // Get bill by ID
  Future<Map<String, dynamic>?> getBillById(int id) async {
    final result = await _db.rawQuery(
      '''SELECT b.*, c.name as customer_name
      FROM bills b
      LEFT JOIN customers c ON b.customer_id = c.id
      WHERE b.id = ? AND b.is_deleted = 0''',
      [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Get bill items by bill ID
  Future<List<Map<String, dynamic>>> getBillItems(int billId) async {
    return await _db.rawQuery(
      '''SELECT * FROM bill_items
      WHERE bill_id = ? AND is_deleted = 0
      ORDER BY id''',
      [billId],
    );
  }

  // Delete bill (soft delete)
  Future<int> deleteBill(int id) async {
    return await _db.rawUpdate(
      '''UPDATE bills SET is_deleted = 1, updated_at = datetime('now')
      WHERE id = ?''',
      [id],
    );
  }
}
