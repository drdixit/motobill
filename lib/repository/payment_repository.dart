import 'package:sqflite/sqflite.dart';
import '../model/payment_summary.dart';

class PaymentRepository {
  final Database _db;

  PaymentRepository(this._db);

  /// Get all customers with receivables (customers who owe us money)
  /// Takes into account credit notes - only counts max_refundable_amount
  Future<List<PaymentSummary>> getReceivables() async {
    try {
      final result = await _db.rawQuery('''
        SELECT
          c.id,
          c.name,
          c.phone,
          'customer' as type,
          COALESCE(SUM(b.total_amount), 0) as total_amount,
          COALESCE(SUM(b.paid_amount), 0) as paid_amount,
          COALESCE(SUM(
            CASE
              WHEN b.payment_status IN ('unpaid', 'partial')
              THEN b.total_amount - b.paid_amount
              ELSE 0
            END
          ), 0) as bill_remaining,
          COALESCE(SUM(
            CASE
              WHEN cn.id IS NOT NULL
              THEN cn.max_refundable_amount - COALESCE(cn.refunded_amount, 0)
              ELSE 0
            END
          ), 0) as credit_note_refundable,
          COUNT(DISTINCT b.id) as bill_count,
          COUNT(DISTINCT CASE
            WHEN b.payment_status IN ('unpaid', 'partial')
            THEN b.id
          END) as pending_bill_count
        FROM customers c
        INNER JOIN bills b ON c.id = b.customer_id
        LEFT JOIN credit_notes cn ON b.id = cn.bill_id AND cn.is_deleted = 0 AND cn.refund_status != 'refunded'
        WHERE b.is_deleted = 0
          AND c.is_deleted = 0
        GROUP BY c.id, c.name, c.phone
        HAVING (bill_remaining - credit_note_refundable) > 0.01
        ORDER BY (bill_remaining - credit_note_refundable) DESC
      ''');

      // Transform the result to match PaymentSummary structure
      return result.map((row) {
        final billRemaining = (row['bill_remaining'] as num).toDouble();
        final creditNoteRefundable = (row['credit_note_refundable'] as num)
            .toDouble();
        final netRemaining = billRemaining - creditNoteRefundable;

        // Use pending_bill_count for more accurate count
        final pendingBillCount = (row['pending_bill_count'] as num).toInt();

        return PaymentSummary.fromJson({
          'id': row['id'],
          'name': row['name'],
          'phone': row['phone'],
          'type': row['type'],
          'total_amount': row['total_amount'],
          'paid_amount': row['paid_amount'],
          'remaining_amount': netRemaining,
          'bill_count': pendingBillCount,
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to get receivables: $e');
    }
  }

  /// Get all vendors with payables (vendors we owe money to)
  /// Takes into account purchase payments and debit notes
  Future<List<PaymentSummary>> getPayables() async {
    try {
      final result = await _db.rawQuery('''
        SELECT
          v.id,
          v.name,
          v.phone,
          'vendor' as type,
          COALESCE(SUM(p.total_amount), 0) as total_amount,
          COALESCE(SUM(p.paid_amount), 0) as paid_amount,
          COALESCE(SUM(
            CASE
              WHEN p.payment_status IN ('unpaid', 'partial')
              THEN p.total_amount - p.paid_amount
              ELSE 0
            END
          ), 0) as purchase_remaining,
          COALESCE(SUM(
            CASE
              WHEN dn.id IS NOT NULL
              THEN dn.max_refundable_amount - COALESCE(dn.refunded_amount, 0)
              ELSE 0
            END
          ), 0) as debit_note_refundable,
          COUNT(DISTINCT p.id) as bill_count
        FROM vendors v
        INNER JOIN purchases p ON v.id = p.vendor_id
        LEFT JOIN debit_notes dn ON p.id = dn.purchase_id AND dn.is_deleted = 0 AND dn.refund_status != 'refunded'
        WHERE p.is_deleted = 0
          AND v.is_deleted = 0
        GROUP BY v.id, v.name, v.phone
        HAVING (purchase_remaining - debit_note_refundable) > 0.01
        ORDER BY (purchase_remaining - debit_note_refundable) DESC
      ''');

      // Transform the result to match PaymentSummary structure
      return result.map((row) {
        final purchaseRemaining = (row['purchase_remaining'] as num).toDouble();
        final debitNoteRefundable = (row['debit_note_refundable'] as num)
            .toDouble();
        final netRemaining = purchaseRemaining - debitNoteRefundable;

        return PaymentSummary.fromJson({
          'id': row['id'],
          'name': row['name'],
          'phone': row['phone'],
          'type': row['type'],
          'total_amount': row['total_amount'],
          'paid_amount': row['paid_amount'],
          'remaining_amount': netRemaining,
          'bill_count': row['bill_count'],
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to get payables: $e');
    }
  }

  /// Get all customers with pending refunds (what we owe them for credit notes)
  Future<List<PaymentSummary>> getCustomerRefundables() async {
    try {
      final result = await _db.rawQuery('''
        SELECT
          c.id,
          c.name,
          c.phone,
          'customer' as type,
          COALESCE(SUM(cn.total_amount), 0) as total_amount,
          COALESCE(SUM(cn.refunded_amount), 0) as paid_amount,
          COALESCE(SUM(cn.max_refundable_amount - COALESCE(cn.refunded_amount, 0)), 0) as remaining_amount,
          COUNT(cn.id) as bill_count
        FROM customers c
        INNER JOIN credit_notes cn ON c.id = cn.customer_id
        WHERE cn.is_deleted = 0
          AND c.is_deleted = 0
          AND cn.refund_status != 'refunded'
          AND (cn.max_refundable_amount - COALESCE(cn.refunded_amount, 0)) > 0.01
        GROUP BY c.id, c.name, c.phone
        HAVING remaining_amount > 0.01
        ORDER BY remaining_amount DESC
      ''');

      return result.map((e) => PaymentSummary.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to get customer refundables: $e');
    }
  }

  /// Get payment summary statistics
  /// Receivables adjusted for credit notes (only max_refundable_amount)
  /// Payables adjusted for purchase payments and debit notes
  Future<Map<String, double>> getPaymentStats() async {
    try {
      // Get total receivables minus credit note refundables
      final receivablesResult = await _db.rawQuery('''
        SELECT
          COALESCE(SUM(
            CASE
              WHEN b.payment_status IN ('unpaid', 'partial')
              THEN b.total_amount - b.paid_amount
              ELSE 0
            END
          ), 0) as bill_remaining,
          COALESCE(SUM(
            CASE
              WHEN cn.id IS NOT NULL
              THEN cn.max_refundable_amount - COALESCE(cn.refunded_amount, 0)
              ELSE 0
            END
          ), 0) as credit_note_refundable
        FROM bills b
        LEFT JOIN credit_notes cn ON b.id = cn.bill_id AND cn.is_deleted = 0 AND cn.refund_status != 'refunded'
        WHERE b.is_deleted = 0
      ''');

      // Get total payables (purchases - payments - debit notes)
      final payablesResult = await _db.rawQuery('''
        SELECT
          COALESCE(SUM(
            CASE
              WHEN p.payment_status IN ('unpaid', 'partial')
              THEN p.total_amount - p.paid_amount
              ELSE 0
            END
          ), 0) as purchase_remaining,
          COALESCE(SUM(
            CASE
              WHEN dn.id IS NOT NULL
              THEN dn.max_refundable_amount - COALESCE(dn.refunded_amount, 0)
              ELSE 0
            END
          ), 0) as debit_note_refundable
        FROM purchases p
        LEFT JOIN debit_notes dn ON p.id = dn.purchase_id AND dn.is_deleted = 0 AND dn.refund_status != 'refunded'
        WHERE p.is_deleted = 0
      ''');

      // Get customer refundables (what we owe customers)
      final customerRefundablesResult = await _db.rawQuery('''
        SELECT COALESCE(SUM(cn.max_refundable_amount - COALESCE(cn.refunded_amount, 0)), 0) as customer_refundables
        FROM credit_notes cn
        WHERE cn.is_deleted = 0
          AND cn.refund_status != 'refunded'
          AND (cn.max_refundable_amount - COALESCE(cn.refunded_amount, 0)) > 0.01
      ''');

      // Get vendor refundables (what vendors owe us for debit notes)
      final vendorRefundablesResult = await _db.rawQuery('''
        SELECT COALESCE(SUM(dn.max_refundable_amount - COALESCE(dn.refunded_amount, 0)), 0) as vendor_refundables
        FROM debit_notes dn
        WHERE dn.is_deleted = 0
          AND dn.refund_status != 'refunded'
          AND (dn.max_refundable_amount - COALESCE(dn.refunded_amount, 0)) > 0.01
      ''');

      final billRemaining = (receivablesResult.first['bill_remaining'] as num)
          .toDouble();
      final creditNoteRefundable =
          (receivablesResult.first['credit_note_refundable'] as num).toDouble();

      final purchaseRemaining =
          (payablesResult.first['purchase_remaining'] as num).toDouble();
      final debitNoteRefundable =
          (payablesResult.first['debit_note_refundable'] as num).toDouble();

      // Calculate vendor payables/receivables
      // If debit_note_refundable > purchase_remaining, vendors owe us money
      // Otherwise, we owe vendors money
      final vendorPayables = purchaseRemaining > debitNoteRefundable
          ? purchaseRemaining - debitNoteRefundable
          : 0.0;
      final vendorReceivables = debitNoteRefundable > purchaseRemaining
          ? debitNoteRefundable - purchaseRemaining
          : 0.0;

      final customerRefundables =
          (customerRefundablesResult.first['customer_refundables'] as num)
              .toDouble();

      final vendorRefundables =
          (vendorRefundablesResult.first['vendor_refundables'] as num)
              .toDouble();

      // Total receivables = what customers owe us (bills - credit notes) + what vendors owe us (when returns > purchases)
      // Total payables = what we owe vendors (purchases - returns) + what we owe customers (refunds)
      final totalReceivables =
          (billRemaining - creditNoteRefundable) + vendorReceivables;
      final totalPayables = vendorPayables + customerRefundables;

      return {
        'total_receivables': totalReceivables,
        'total_payables': totalPayables,
        'vendor_payables': vendorPayables,
        'vendor_receivables': vendorReceivables,
        'customer_refundables': customerRefundables,
        'vendor_refundables': vendorRefundables,
        'net_position': totalReceivables - totalPayables,
      };
    } catch (e) {
      throw Exception('Failed to get payment stats: $e');
    }
  }
}
