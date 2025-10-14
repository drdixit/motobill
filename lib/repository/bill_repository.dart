import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../model/bill.dart';

class BillRepository {
  final Database _db;

  BillRepository(this._db);

  // Generate a new bill number using date prefix (ddmmyy) and a daily sequence
  Future<String> generateBillNumber() async {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString().substring(2);
    final datePrefix = '$day$month$year';

    final last = await _db.rawQuery(
      '''SELECT bill_number FROM bills
         WHERE bill_number LIKE ? AND is_deleted = 0
         ORDER BY bill_number DESC LIMIT 1''',
      ['$datePrefix%'],
    );

    int sequenceNumber = 1;
    if (last.isNotEmpty) {
      try {
        final lastNumber = last.first['bill_number'] as String;
        final lastSeq = int.parse(lastNumber.substring(6));
        sequenceNumber = lastSeq + 1;
      } catch (_) {
        sequenceNumber = 1;
      }
    }

    return '$datePrefix${sequenceNumber.toString().padLeft(5, '0')}';
  }

  // Generate a new credit note number (same pattern as bills)
  Future<String> generateCreditNoteNumber() async {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString().substring(2);
    final datePrefix = '$day$month$year';

    final last = await _db.rawQuery(
      '''SELECT credit_note_number FROM credit_notes
         WHERE credit_note_number LIKE ? AND is_deleted = 0
         ORDER BY credit_note_number DESC LIMIT 1''',
      ['$datePrefix%'],
    );

    int sequenceNumber = 1;
    if (last.isNotEmpty) {
      try {
        final lastNumber = last.first['credit_note_number'] as String;
        final lastSeq = int.parse(lastNumber.substring(6));
        sequenceNumber = lastSeq + 1;
      } catch (_) {
        sequenceNumber = 1;
      }
    }

    return '$datePrefix${sequenceNumber.toString().padLeft(5, '0')}';
  }

  // Create a bill and its items inside a transaction
  Future<int> createBill(Bill bill, List<BillItem> items) async {
    return await _db.transaction((txn) async {
      final billId = await txn.rawInsert(
        '''INSERT INTO bills (bill_number, customer_id, subtotal, tax_amount, total_amount, created_at, updated_at, is_deleted)
           VALUES (?, ?, ?, ?, ?, ?, ?, 0)''',
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

      for (final it in items) {
        // First, check stock availability
        final stockCheck = await txn.rawQuery(
          '''SELECT COALESCE(SUM(quantity_remaining), 0) as available
             FROM stock_batches
             WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0''',
          [it.productId],
        );

        final availableQty = stockCheck.isNotEmpty
            ? (stockCheck.first['available'] as num).toInt()
            : 0;

        // If insufficient stock, check negative_allow flag
        if (availableQty < it.quantity) {
          // Get product's negative_allow flag
          final productCheck = await txn.rawQuery(
            'SELECT negative_allow FROM products WHERE id = ? AND is_deleted = 0',
            [it.productId],
          );

          final negativeAllow = productCheck.isNotEmpty
              ? (productCheck.first['negative_allow'] as int) == 1
              : false;

          if (negativeAllow) {
            // Product allows negative stock - create auto-purchase
            final shortage = it.quantity - availableQty;
            await _createAutoPurchaseForShortage(
              txn,
              billId,
              it.productId,
              it.productName,
              it.partNumber,
              it.hsnCode,
              it.uqcCode,
              it.costPrice,
              shortage,
            );
          } else {
            // Product does NOT allow negative stock - throw error
            throw Exception(
              'Insufficient stock for ${it.productName}. Available: $availableQty, Required: ${it.quantity}',
            );
          }
        }

        // Insert bill item
        final billItemId = await txn.rawInsert(
          '''INSERT INTO bill_items
             (bill_id, product_id, product_name, part_number, hsn_code, uqc_code, cost_price, selling_price, quantity, subtotal, cgst_rate, sgst_rate, igst_rate, utgst_rate, cgst_amount, sgst_amount, igst_amount, utgst_amount, tax_amount, total_amount, is_deleted)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            billId,
            it.productId,
            it.productName,
            it.partNumber,
            it.hsnCode,
            it.uqcCode,
            it.costPrice,
            it.sellingPrice,
            it.quantity,
            it.subtotal,
            it.cgstRate,
            it.sgstRate,
            it.igstRate,
            it.utgstRate,
            it.cgstAmount,
            it.sgstAmount,
            it.igstAmount,
            it.utgstAmount,
            it.taxAmount,
            it.totalAmount,
            0, // is_deleted
          ],
        );

        // Allocate stock using FIFO (First In First Out)
        int remainingQty = it.quantity;

        // Get stock batches ordered by ID (oldest first)
        final batches = await txn.rawQuery(
          '''SELECT id, quantity_remaining, cost_price
             FROM stock_batches
             WHERE product_id = ? AND is_deleted = 0 AND quantity_remaining > 0
             ORDER BY id ASC''',
          [it.productId],
        );

        for (final batch in batches) {
          if (remainingQty <= 0) break;

          final batchId = batch['id'] as int;
          final qtyRemaining = (batch['quantity_remaining'] as num).toInt();
          final batchCostPrice = (batch['cost_price'] as num).toDouble();

          if (qtyRemaining <= 0) continue;

          // Allocate as much as possible from this batch
          final allocate = remainingQty > qtyRemaining
              ? qtyRemaining
              : remainingQty;

          // Deduct from stock batch
          await txn.rawUpdate(
            '''UPDATE stock_batches
               SET quantity_remaining = quantity_remaining - ?,
                   updated_at = datetime('now')
               WHERE id = ?''',
            [allocate, batchId],
          );

          // Record stock batch usage
          await txn.rawInsert(
            '''INSERT INTO stock_batch_usage
               (bill_item_id, stock_batch_id, quantity_used, cost_price, created_at)
               VALUES (?, ?, ?, ?, datetime('now'))''',
            [billItemId, batchId, allocate, batchCostPrice],
          );

          remainingQty -= allocate;
        }

        // If there's still remaining quantity (shouldn't happen after validation)
        if (remainingQty > 0) {
          throw Exception(
            'Failed to allocate stock for ${it.productName}. Missing: $remainingQty units',
          );
        }
      }

      return billId;
    });
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
      '''SELECT b.*,
         c.name as customer_name,
         c.legal_name as customer_legal_name,
         c.gst_number as customer_gst_number,
         c.phone as customer_phone,
         c.email as customer_email,
         c.address_line1 as customer_address_line1,
         c.address_line2 as customer_address_line2,
         c.city as customer_city,
         c.state as customer_state,
         c.pincode as customer_pincode
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

  // Get already returned quantities for a bill grouped by bill_item_id
  // Returns a map of bill_item_id -> returnedQuantity
  Future<Map<int, int>> getReturnedQuantitiesForBill(int billId) async {
    final rows = await _db.rawQuery(
      '''SELECT cni.bill_item_id as bill_item_id, SUM(cni.quantity) as returned_qty
         FROM credit_note_items cni
         INNER JOIN credit_notes cn ON cni.credit_note_id = cn.id
         WHERE cn.bill_id = ? AND cni.is_deleted = 0 AND cn.is_deleted = 0
         GROUP BY cni.bill_item_id''',
      [billId],
    );

    final Map<int, int> result = {};
    for (final r in rows) {
      final key = r['bill_item_id'] as int;
      final qty = (r['returned_qty'] as num).toInt();
      result[key] = qty;
    }
    return result;
  }

  // Create credit note and credit note items transactionally.
  // creditNoteData: map with keys (bill_id, credit_note_number, customer_id, subtotal, tax_amount, total_amount)
  // items: list of maps that match credit_note_items columns (bill_item_id, product_id, product_name, part_number, hsn_code, uqc_code, selling_price, quantity, subtotal, cgst_rate, sgst_rate, igst_rate, utgst_rate, cgst_amount, sgst_amount, igst_amount, utgst_amount, tax_amount, total_amount)
  Future<int> createCreditNote(
    Map<String, dynamic> creditNoteData,
    List<Map<String, dynamic>> items,
  ) async {
    return await _db.transaction((txn) async {
      // Generate credit note number inside transaction to avoid race conditions
      final now = DateTime.now();
      final day = now.day.toString().padLeft(2, '0');
      final month = now.month.toString().padLeft(2, '0');
      final year = now.year.toString().substring(2);
      final datePrefix = '$day$month$year';

      final last = await txn.rawQuery(
        '''SELECT credit_note_number FROM credit_notes
           WHERE credit_note_number LIKE ? AND is_deleted = 0
           ORDER BY credit_note_number DESC LIMIT 1''',
        ['$datePrefix%'],
      );

      int sequenceNumber = 1;
      if (last.isNotEmpty) {
        try {
          final lastNumber = last.first['credit_note_number'] as String;
          final lastSeq = int.parse(lastNumber.substring(6));
          if (lastSeq >= 99999)
            throw Exception('Daily credit note limit reached (99,999).');
          sequenceNumber = lastSeq + 1;
        } catch (_) {
          sequenceNumber = 1;
        }
      }

      final creditNoteNumber =
          '$datePrefix${sequenceNumber.toString().padLeft(5, '0')}';

      final creditNoteId = await txn.rawInsert(
        '''INSERT INTO credit_notes
          (bill_id, credit_note_number, customer_id, reason, subtotal, tax_amount, total_amount, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
        [
          creditNoteData['bill_id'],
          creditNoteNumber,
          creditNoteData['customer_id'],
          creditNoteData['reason'],
          creditNoteData['subtotal'],
          creditNoteData['tax_amount'],
          creditNoteData['total_amount'],
        ],
      );

      // Validate per-item allowed quantities inside transaction
      for (final it in items) {
        final billItemId = it['bill_item_id'] as int;
        // get original bought qty
        final boughtRows = await txn.rawQuery(
          'SELECT quantity FROM bill_items WHERE id = ?',
          [billItemId],
        );
        if (boughtRows.isEmpty)
          throw Exception('Bill item not found: $billItemId');
        final boughtQty = (boughtRows.first['quantity'] as num).toInt();

        // get already returned for this bill_item inside txn
        final returnedRows = await txn.rawQuery(
          '''SELECT COALESCE(SUM(cni.quantity), 0) as returned_sum
             FROM credit_note_items cni
             INNER JOIN credit_notes cn ON cni.credit_note_id = cn.id
             WHERE cni.bill_item_id = ? AND cn.is_deleted = 0 AND cni.is_deleted = 0''',
          [billItemId],
        );
        final alreadyReturned = returnedRows.isNotEmpty
            ? (returnedRows.first['returned_sum'] as num).toInt()
            : 0;

        if (alreadyReturned + (it['quantity'] as int) > boughtQty) {
          throw Exception(
            'Return quantity exceeds purchased quantity for bill_item_id $billItemId',
          );
        }
      }

      for (final it in items) {
        // Insert credit_note_item and get its id
        final creditNoteItemId = await txn.rawInsert(
          '''INSERT INTO credit_note_items
            (credit_note_id, bill_item_id, product_id, product_name, part_number, hsn_code, uqc_code, selling_price, quantity, subtotal, cgst_rate, sgst_rate, igst_rate, utgst_rate, cgst_amount, sgst_amount, igst_amount, utgst_amount, tax_amount, total_amount, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
          [
            creditNoteId,
            it['bill_item_id'],
            it['product_id'],
            it['product_name'],
            it['part_number'],
            it['hsn_code'],
            it['uqc_code'],
            it['selling_price'],
            it['quantity'],
            it['subtotal'],
            it['cgst_rate'],
            it['sgst_rate'],
            it['igst_rate'],
            it['utgst_rate'],
            it['cgst_amount'],
            it['sgst_amount'],
            it['igst_amount'],
            it['utgst_amount'],
            it['tax_amount'],
            it['total_amount'],
          ],
        );

        // Allocate returned quantity back to stock batches based on original usage
        int remainingToReturn = it['quantity'] as int;
        final billItemId = it['bill_item_id'] as int;

        // Get stock_batch_usage records for this bill_item ordered by id DESC (attempt to return to most recent batches first)
        final usages = await txn.rawQuery(
          '''SELECT id, stock_batch_id, quantity_used, cost_price
             FROM stock_batch_usage
             WHERE bill_item_id = ?
             ORDER BY id DESC''',
          [billItemId],
        );

        for (final usage in usages) {
          if (remainingToReturn <= 0) break;

          final stockBatchId = usage['stock_batch_id'] as int;
          final usedQty = usage['quantity_used'] as int;
          final costPrice = (usage['cost_price'] as num).toDouble();

          // Calculate how many have already been returned for this bill_item -> stock_batch
          final prevReturns = await txn.rawQuery(
            '''SELECT COALESCE(SUM(cnbr.quantity_returned), 0) as returned_sum
               FROM credit_note_batch_returns cnbr
               INNER JOIN credit_note_items cni ON cnbr.credit_note_item_id = cni.id
               WHERE cni.bill_item_id = ? AND cnbr.stock_batch_id = ?''',
            [billItemId, stockBatchId],
          );

          final prevReturned = prevReturns.isNotEmpty
              ? (prevReturns.first['returned_sum'] as num).toInt()
              : 0;
          final availableFromUsage = usedQty - prevReturned;
          if (availableFromUsage <= 0) continue;

          final allocate = remainingToReturn > availableFromUsage
              ? availableFromUsage
              : remainingToReturn;

          // Update batch quantity
          await txn.rawUpdate(
            '''UPDATE stock_batches
               SET quantity_remaining = quantity_remaining + ?,
               updated_at = datetime('now')
               WHERE id = ?''',
            [allocate, stockBatchId],
          );

          // Record credit note batch return
          await txn.rawInsert(
            '''INSERT INTO credit_note_batch_returns
               (credit_note_item_id, stock_batch_id, quantity_returned, cost_price, created_at)
               VALUES (?, ?, ?, ?, datetime('now'))''',
            [creditNoteItemId, stockBatchId, allocate, costPrice],
          );

          remainingToReturn -= allocate;
        }

        // If still remaining, create a new stock batch for returned items
        if (remainingToReturn > 0) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final batchNumber =
              'RETURN-$creditNoteId-${it['product_id']}-$timestamp';
          // purchase_item_id defaulted to 0 for returned batch
          final newBatchId = await txn.rawInsert(
            '''INSERT INTO stock_batches
               (product_id, purchase_item_id, batch_number, quantity_received, quantity_remaining, cost_price, created_at, updated_at)
               VALUES (?, 0, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
            [
              it['product_id'],
              batchNumber,
              remainingToReturn,
              remainingToReturn,
              it['selling_price'],
            ],
          );

          await txn.rawInsert(
            '''INSERT INTO credit_note_batch_returns
               (credit_note_item_id, stock_batch_id, quantity_returned, cost_price, created_at)
               VALUES (?, ?, ?, ?, datetime('now'))''',
            [
              creditNoteItemId,
              newBatchId,
              remainingToReturn,
              it['selling_price'],
            ],
          );

          remainingToReturn = 0;
        }
      }

      return creditNoteId;
    });
  }

  // Delete bill (soft delete)
  Future<int> deleteBill(int id) async {
    return await _db.rawUpdate(
      '''UPDATE bills SET is_deleted = 1, updated_at = datetime('now')
      WHERE id = ?''',
      [id],
    );
  }

  // Helper method to create auto-purchase for stock shortage
  // This duplicates logic from PurchaseRepository to avoid circular dependency
  Future<void> _createAutoPurchaseForShortage(
    Transaction txn,
    int sourceBillId,
    int productId,
    String productName,
    String? partNumber,
    String? hsnCode,
    String? uqcCode,
    double costPrice,
    int shortage,
  ) async {
    final now = DateTime.now();

    // Generate auto-purchase number in format: AUTO-DDMMYYXXXXX
    // Example: AUTO-14102500001 for 14 Oct 2025, first auto-purchase
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString().substring(2); // Last 2 digits of year
    final datePrefix = 'AUTO-$day$month$year'; // AUTO-DDMMYY

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
        sequenceNumber = lastSequence + 1;
      }
    }

    // Format: AUTO-DDMMYYXXXXX (4 chars prefix + 6 chars date + 5 digits sequence)
    final purchaseNumber =
        '$datePrefix${sequenceNumber.toString().padLeft(5, '0')}';

    // Auto-stock vendor ID is 7
    const autoStockVendorId = 7;

    // For auto-purchases, we keep it simple: no tax breakdown
    final subtotal = costPrice * shortage;
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
        null,
        null,
        autoStockVendorId,
        subtotal,
        0.0,
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
        shortage,
        subtotal,
        totalAmount,
      ],
    );

    // Create stock batch
    final timestamp = now.millisecondsSinceEpoch;
    final batchNumber = 'BATCH-$purchaseId-$productId-$timestamp';

    await txn.rawInsert(
      '''INSERT INTO stock_batches
      (product_id, purchase_item_id, batch_number, quantity_received,
      quantity_remaining, cost_price, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
      [productId, purchaseItemId, batchNumber, shortage, shortage, costPrice],
    );
  }
}
