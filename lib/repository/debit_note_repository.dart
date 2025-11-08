import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DebitNoteRepository {
  final Database _db;

  DebitNoteRepository(this._db);

  Future<List<Map<String, dynamic>>> getAllDebitNotes() async {
    return await _db.rawQuery('''
      SELECT dn.*, v.name as vendor_name
      FROM debit_notes dn
      LEFT JOIN vendors v ON dn.vendor_id = v.id
      WHERE dn.is_deleted = 0
      ORDER BY dn.id DESC
    ''');
  }

  // Get debit notes within date range
  Future<List<Map<String, dynamic>>> getDebitNotesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startStr = startDate.toIso8601String().split('T')[0];
    final endStr = endDate.toIso8601String().split('T')[0];

    return await _db.rawQuery(
      '''
      SELECT dn.*, v.name as vendor_name
      FROM debit_notes dn
      LEFT JOIN vendors v ON dn.vendor_id = v.id
      WHERE dn.is_deleted = 0
      AND DATE(dn.created_at) BETWEEN ? AND ?
      ORDER BY dn.id DESC
    ''',
      [startStr, endStr],
    );
  }

  Future<List<Map<String, dynamic>>> getDebitNoteItems(int debitNoteId) async {
    return await _db.rawQuery(
      '''SELECT dni.*, dn.debit_note_number, dn.reason, v.name as vendor_name
         FROM debit_note_items dni
         LEFT JOIN debit_notes dn ON dni.debit_note_id = dn.id
         LEFT JOIN vendors v ON dn.vendor_id = v.id
         WHERE dni.debit_note_id = ? AND dni.is_deleted = 0
         ORDER BY dni.id''',
      [debitNoteId],
    );
  }

  Future<int> createDebitNote(
    Map<String, dynamic> debitNoteData,
    List<Map<String, dynamic>> items,
  ) async {
    return await _db.transaction((txn) async {
      // Validate stock availability before creating debit note
      for (final it in items) {
        final purchaseItemId = it['purchase_item_id'] as int;
        final qtyToReturn = it['quantity'] as int;

        // Check available stock for this purchase item
        final stockCheck = await txn.rawQuery(
          '''SELECT COALESCE(SUM(quantity_remaining), 0) as available
             FROM stock_batches
             WHERE purchase_item_id = ? AND is_deleted = 0''',
          [purchaseItemId],
        );

        final availableStock = (stockCheck.first['available'] as num).toInt();

        if (availableStock < qtyToReturn) {
          throw Exception(
            'Insufficient stock to return. Available: $availableStock, Requested: $qtyToReturn for "${it['product_name']}"',
          );
        }
      }

      // generate debit note number within txn
      final now = DateTime.now();
      final day = now.day.toString().padLeft(2, '0');
      final month = now.month.toString().padLeft(2, '0');
      final year = now.year.toString().substring(2);
      final prefix = '$day$month$year';

      final last = await txn.rawQuery(
        '''SELECT debit_note_number FROM debit_notes WHERE debit_note_number LIKE ? AND is_deleted = 0 ORDER BY debit_note_number DESC LIMIT 1''',
        ['$prefix%'],
      );

      int sequence = 1;
      if (last.isNotEmpty) {
        try {
          final lastNum = last.first['debit_note_number'] as String;
          final lastSeq = int.parse(lastNum.substring(6));
          if (lastSeq >= 99999)
            throw Exception('Daily debit note limit reached');
          sequence = lastSeq + 1;
        } catch (_) {
          sequence = 1;
        }
      }

      final debitNoteNumber = '$prefix${sequence.toString().padLeft(5, '0')}';

      // Calculate max_refundable_amount based on purchase's paid amount
      // Similar logic to credit notes but for purchases
      final purchaseResult = await txn.rawQuery(
        'SELECT total_amount, paid_amount FROM purchases WHERE id = ?',
        [debitNoteData['purchase_id']],
      );

      if (purchaseResult.isEmpty) {
        throw Exception('Purchase not found');
      }

      final totalAmount = (purchaseResult.first['total_amount'] as num)
          .toDouble();
      final paidAmount = (purchaseResult.first['paid_amount'] as num)
          .toDouble();
      final purchaseRemaining = totalAmount - paidAmount;

      // Get total return amount and max_refundable from all previous debit notes
      final previousResult = await txn.rawQuery(
        '''SELECT
           COALESCE(SUM(total_amount), 0) as total_returned,
           COALESCE(SUM(max_refundable_amount), 0) as total_allocated
           FROM debit_notes
           WHERE purchase_id = ? AND is_deleted = 0''',
        [debitNoteData['purchase_id']],
      );

      final totalReturned = previousResult.isNotEmpty
          ? (previousResult.first['total_returned'] as num).toDouble()
          : 0.0;
      final alreadyAllocated = previousResult.isNotEmpty
          ? (previousResult.first['total_allocated'] as num).toDouble()
          : 0.0;

      final debitNoteAmount = (debitNoteData['total_amount'] as num).toDouble();

      // Calculate max refundable based on business logic:
      // Vendor should only get refund for the VALUE OF RETURNED PRODUCTS
      // Limited by how much they actually paid

      final netPurchaseRemaining = purchaseRemaining - totalReturned;
      final newNetRemaining = netPurchaseRemaining - debitNoteAmount;

      double maxRefundableAmount;
      String refundStatus;

      if (newNetRemaining >= 0.01) {
        // Vendor still owes money after return, no cash refund
        maxRefundableAmount = 0.0;
        refundStatus = 'adjusted';
      } else {
        // Return value exceeds purchase remaining, vendor eligible for refund
        double thisReturnRefundable;
        if (netPurchaseRemaining >= 0.01) {
          thisReturnRefundable = debitNoteAmount - netPurchaseRemaining;
        } else {
          thisReturnRefundable = debitNoteAmount;
        }

        // Limit by available funds (what's left from paid amount)
        final availableToRefund = paidAmount - alreadyAllocated;

        if (availableToRefund < 0.01 || thisReturnRefundable < 0.01) {
          maxRefundableAmount = 0.0;
          refundStatus = 'adjusted';
        } else {
          maxRefundableAmount = (thisReturnRefundable < availableToRefund)
              ? thisReturnRefundable
              : availableToRefund;
          refundStatus = 'pending';
        }
      }

      final debitNoteId = await txn.rawInsert(
        '''INSERT INTO debit_notes (purchase_id, debit_note_number, vendor_id, reason, subtotal, tax_amount, total_amount, max_refundable_amount, refund_status, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
        [
          debitNoteData['purchase_id'],
          debitNoteNumber,
          debitNoteData['vendor_id'],
          debitNoteData['reason'],
          debitNoteData['subtotal'],
          debitNoteData['tax_amount'],
          debitNoteData['total_amount'],
          maxRefundableAmount,
          refundStatus,
        ],
      );

      // validate quantities against purchase items
      for (final it in items) {
        final purchaseItemId = it['purchase_item_id'] as int;
        final boughtRows = await txn.rawQuery(
          'SELECT quantity FROM purchase_items WHERE id = ?',
          [purchaseItemId],
        );
        if (boughtRows.isEmpty)
          throw Exception('Purchase item not found: $purchaseItemId');
        final boughtQty = (boughtRows.first['quantity'] as num).toInt();

        // already returned via existing debit notes
        final returnedRows = await txn.rawQuery(
          '''SELECT COALESCE(SUM(dni.quantity),0) as returned_sum
             FROM debit_note_items dni
             INNER JOIN debit_notes dn ON dni.debit_note_id = dn.id
             WHERE dni.purchase_item_id = ? AND dn.is_deleted = 0 AND dni.is_deleted = 0''',
          [purchaseItemId],
        );
        final alreadyReturned = returnedRows.isNotEmpty
            ? (returnedRows.first['returned_sum'] as num).toInt()
            : 0;

        if (alreadyReturned + (it['quantity'] as int) > boughtQty) {
          throw Exception(
            'Return quantity exceeds purchased quantity for purchase_item_id $purchaseItemId',
          );
        }
      }

      // insert debit note items and update stock batches (decrease quantity_remaining)
      for (final it in items) {
        final debitNoteItemId = await txn.rawInsert(
          '''INSERT INTO debit_note_items
             (debit_note_id, purchase_item_id, product_id, product_name, part_number, hsn_code, uqc_code, cost_price, quantity, subtotal, cgst_rate, sgst_rate, igst_rate, utgst_rate, cgst_amount, sgst_amount, igst_amount, utgst_amount, tax_amount, total_amount, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
          [
            debitNoteId,
            it['purchase_item_id'],
            it['product_id'],
            it['product_name'],
            it['part_number'],
            it['hsn_code'],
            it['uqc_code'],
            it['cost_price'],
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

        int remainingToRemove = it['quantity'] as int;
        final purchaseItemId = it['purchase_item_id'] as int;
        final productId = it['product_id'] as int;

        // Get stock batches available for this product ordered by id ASC (oldest first) to reduce stock
        // Priority: 1) Original purchase batches, 2) Return batches (purchase_item_id = 0)
        final batches = await txn.rawQuery(
          '''SELECT id, quantity_remaining, cost_price, purchase_item_id
             FROM stock_batches
             WHERE (purchase_item_id = ? OR (product_id = ? AND purchase_item_id = 0))
               AND is_deleted = 0
               AND quantity_remaining > 0
             ORDER BY
               CASE WHEN purchase_item_id = ? THEN 0 ELSE 1 END,
               id ASC''',
          [purchaseItemId, productId, purchaseItemId],
        );

        for (final batch in batches) {
          if (remainingToRemove <= 0) break;
          final batchId = batch['id'] as int;
          final qtyRemaining = (batch['quantity_remaining'] as num).toInt();
          final costPrice = (batch['cost_price'] as num).toDouble();
          if (qtyRemaining <= 0) continue;

          final allocate = remainingToRemove > qtyRemaining
              ? qtyRemaining
              : remainingToRemove;

          // decrease batch remaining
          await txn.rawUpdate(
            'UPDATE stock_batches SET quantity_remaining = quantity_remaining - ?, updated_at = datetime(\'now\') WHERE id = ?',
            [allocate, batchId],
          );

          // record debit note batch return (stock removed)
          await txn.rawInsert(
            '''INSERT INTO debit_note_batch_returns (debit_note_item_id, stock_batch_id, quantity_returned, cost_price, created_at)
               VALUES (?, ?, ?, ?, datetime('now'))''',
            [debitNoteItemId, batchId, allocate, costPrice],
          );

          remainingToRemove -= allocate;
        }

        // If still remaining (shouldn't normally happen if validation passed), record negative batch via new synthetic batch record
        if (remainingToRemove > 0) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final batchNumber =
              'REMOVE-$debitNoteId-${it['product_id']}-$timestamp';
          final newBatchId = await txn.rawInsert(
            '''INSERT INTO stock_batches (product_id, purchase_item_id, batch_number, quantity_received, quantity_remaining, cost_price, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
            [
              it['product_id'],
              0,
              batchNumber,
              0,
              0 - remainingToRemove,
              it['cost_price'] ?? 0.0,
            ],
          );

          await txn.rawInsert(
            '''INSERT INTO debit_note_batch_returns (debit_note_item_id, stock_batch_id, quantity_returned, cost_price, created_at)
               VALUES (?, ?, ?, ?, datetime('now'))''',
            [
              debitNoteItemId,
              newBatchId,
              remainingToRemove,
              it['cost_price'] ?? 0.0,
            ],
          );

          remainingToRemove = 0;
        }
      }

      return debitNoteId;
    });
  }

  /// Get available stock (quantity_remaining) for each purchase item
  /// This includes stock from the original purchase AND any returns (credit notes)
  /// that created new batches for the same product (purchase_item_id = 0)
  /// Does NOT include stock from other purchases of the same product
  Future<Map<int, int>> getAvailableStockForPurchase(int purchaseId) async {
    final result = await _db.rawQuery(
      '''SELECT pi.id as purchase_item_id,
         pi.product_id,
         COALESCE(SUM(sb.quantity_remaining), 0) as available
         FROM purchase_items pi
         LEFT JOIN stock_batches sb ON
           (sb.purchase_item_id = pi.id OR (sb.product_id = pi.product_id AND sb.purchase_item_id = 0))
           AND sb.is_deleted = 0
           AND sb.quantity_remaining > 0
         WHERE pi.purchase_id = ? AND pi.is_deleted = 0
         GROUP BY pi.id, pi.product_id''',
      [purchaseId],
    );

    final Map<int, int> stockMap = {};
    for (final row in result) {
      final purchaseItemId = row['purchase_item_id'] as int;
      final available = (row['available'] as num).toInt();
      stockMap[purchaseItemId] = available;
    }

    return stockMap;
  }

  // ==================== REFUND METHODS ====================

  /// Add a refund to a debit note
  Future<void> addRefund({
    required int debitNoteId,
    required double amount,
    String refundMethod = 'cash',
    DateTime? refundDate,
    String? notes,
  }) async {
    await _db.transaction((txn) async {
      final now = DateTime.now();
      final effectiveRefundDate = refundDate ?? now;

      // Insert refund record
      await txn.rawInsert(
        '''INSERT INTO debit_note_refunds
           (debit_note_id, amount, refund_method, refund_date, notes, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [
          debitNoteId,
          amount,
          refundMethod,
          effectiveRefundDate.toIso8601String(),
          notes,
          now.toIso8601String(),
          now.toIso8601String(),
        ],
      );

      // Get total refunded amount
      final result = await txn.rawQuery(
        '''SELECT COALESCE(SUM(amount), 0) as total_refunded
           FROM debit_note_refunds
           WHERE debit_note_id = ? AND is_deleted = 0''',
        [debitNoteId],
      );

      final totalRefunded = (result.first['total_refunded'] as num).toDouble();

      // Get debit note max refundable amount (based on purchase's paid amount)
      final dnResult = await txn.rawQuery(
        'SELECT max_refundable_amount FROM debit_notes WHERE id = ?',
        [debitNoteId],
      );

      final maxRefundable = (dnResult.first['max_refundable_amount'] as num)
          .toDouble();

      // Validate refund doesn't exceed max refundable amount
      if (totalRefunded > maxRefundable + 0.01) {
        throw Exception(
          'Total refund amount (₹${totalRefunded.toStringAsFixed(2)}) exceeds maximum refundable amount (₹${maxRefundable.toStringAsFixed(2)}). Vendor had only paid ₹${maxRefundable.toStringAsFixed(2)} for this purchase.',
        );
      }

      // Determine refund status (using epsilon for floating-point comparison)
      // Status is based on max_refundable_amount, not total_amount
      String refundStatus;
      if (totalRefunded >= maxRefundable - 0.01) {
        refundStatus = 'refunded';
      } else if (totalRefunded > 0) {
        refundStatus = 'partial';
      } else {
        refundStatus = 'pending';
      }

      // Update debit note
      await txn.rawUpdate(
        '''UPDATE debit_notes
           SET refunded_amount = ?, refund_status = ?, updated_at = ?
           WHERE id = ?''',
        [totalRefunded, refundStatus, now.toIso8601String(), debitNoteId],
      );
    });
  }

  /// Get all refunds for a debit note
  Future<List<Map<String, dynamic>>> getDebitNoteRefunds(
    int debitNoteId,
  ) async {
    final result = await _db.rawQuery(
      '''SELECT * FROM debit_note_refunds
         WHERE debit_note_id = ? AND is_deleted = 0
         ORDER BY refund_date DESC''',
      [debitNoteId],
    );
    return result;
  }

  /// Delete a refund (soft delete)
  Future<void> deleteRefund(int refundId) async {
    await _db.transaction((txn) async {
      final now = DateTime.now();

      // Get refund info before deleting
      final refundResult = await txn.rawQuery(
        'SELECT debit_note_id FROM debit_note_refunds WHERE id = ?',
        [refundId],
      );

      if (refundResult.isEmpty) return;

      final debitNoteId = refundResult.first['debit_note_id'] as int;

      // Soft delete refund
      await txn.rawUpdate(
        '''UPDATE debit_note_refunds
           SET is_deleted = 1, updated_at = ?
           WHERE id = ?''',
        [now.toIso8601String(), refundId],
      );

      // Recalculate total refunded amount
      final result = await txn.rawQuery(
        '''SELECT COALESCE(SUM(amount), 0) as total_refunded
           FROM debit_note_refunds
           WHERE debit_note_id = ? AND is_deleted = 0''',
        [debitNoteId],
      );

      final totalRefunded = (result.first['total_refunded'] as num).toDouble();

      // Get debit note max refundable amount
      final dnResult = await txn.rawQuery(
        'SELECT max_refundable_amount FROM debit_notes WHERE id = ?',
        [debitNoteId],
      );

      final maxRefundable = (dnResult.first['max_refundable_amount'] as num)
          .toDouble();

      // Determine refund status (using epsilon for floating-point comparison)
      String refundStatus;
      if (totalRefunded >= maxRefundable - 0.01) {
        refundStatus = 'refunded';
      } else if (totalRefunded > 0) {
        refundStatus = 'partial';
      } else {
        refundStatus = 'pending';
      }

      // Update debit note
      await txn.rawUpdate(
        '''UPDATE debit_notes
           SET refunded_amount = ?, refund_status = ?, updated_at = ?
           WHERE id = ?''',
        [totalRefunded, refundStatus, now.toIso8601String(), debitNoteId],
      );
    });
  }
}
