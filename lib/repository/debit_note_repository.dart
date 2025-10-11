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

      final debitNoteId = await txn.rawInsert(
        '''INSERT INTO debit_notes (purchase_id, debit_note_number, vendor_id, reason, subtotal, tax_amount, total_amount, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))''',
        [
          debitNoteData['purchase_id'],
          debitNoteNumber,
          debitNoteData['vendor_id'],
          debitNoteData['reason'],
          debitNoteData['subtotal'],
          debitNoteData['tax_amount'],
          debitNoteData['total_amount'],
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

        // Get stock batches available for this product ordered by id ASC (oldest first) to reduce stock
        final batches = await txn.rawQuery(
          '''SELECT id, quantity_remaining, cost_price
             FROM stock_batches
             WHERE purchase_item_id = ? OR product_id = ?
             ORDER BY id ASC''',
          [purchaseItemId, it['product_id']],
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
}
