import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/database_provider.dart';
import '../../../repository/debit_note_repository.dart';

// Provider for debit note details
final debitNoteDetailsProvider = FutureProvider.family<Map<String, dynamic>?, int>((
  ref,
  debitNoteId,
) async {
  final db = await ref.watch(databaseProvider);
  final repository = DebitNoteRepository(db);

  // Fetch debit note with vendor and purchase details
  final debitNoteResult = await db.rawQuery(
    '''
    SELECT dn.*,
           v.name, v.legal_name, v.gst_number, v.phone, v.email,
           v.address_line1, v.address_line2, v.city, v.state, v.pincode,
           p.purchase_number
    FROM debit_notes dn
    LEFT JOIN vendors v ON dn.vendor_id = v.id
    LEFT JOIN purchases p ON dn.purchase_id = p.id
    WHERE dn.id = ? AND dn.is_deleted = 0
    ''',
    [debitNoteId],
  );

  if (debitNoteResult.isEmpty) return null;

  final debitNote = debitNoteResult.first;

  // Fetch debit note items
  final items = await db.rawQuery(
    '''
    SELECT dni.*
    FROM debit_note_items dni
    WHERE dni.debit_note_id = ? AND dni.is_deleted = 0
    ORDER BY dni.id
    ''',
    [debitNoteId],
  );

  // Fetch debit note refunds
  final refunds = await repository.getDebitNoteRefunds(debitNoteId);

  // Separate taxable and non-taxable items
  final taxableItems = items.where((item) {
    final cgstRate = (item['cgst_rate'] as num?) ?? 0;
    final sgstRate = (item['sgst_rate'] as num?) ?? 0;
    final igstRate = (item['igst_rate'] as num?) ?? 0;
    final utgstRate = (item['utgst_rate'] as num?) ?? 0;
    return cgstRate > 0 || sgstRate > 0 || igstRate > 0 || utgstRate > 0;
  }).toList();

  final nonTaxableItems = items.where((item) {
    final cgstRate = (item['cgst_rate'] as num?) ?? 0;
    final sgstRate = (item['sgst_rate'] as num?) ?? 0;
    final igstRate = (item['igst_rate'] as num?) ?? 0;
    final utgstRate = (item['utgst_rate'] as num?) ?? 0;
    return cgstRate == 0 && sgstRate == 0 && igstRate == 0 && utgstRate == 0;
  }).toList();

  // Transform items to match expected format
  final transformedTaxableItems = taxableItems.map((item) {
    final quantity = (item['quantity'] as num?) ?? 0;
    final costPrice = (item['cost_price'] as num?) ?? 0;
    final cgstRate = (item['cgst_rate'] as num?) ?? 0;
    final sgstRate = (item['sgst_rate'] as num?) ?? 0;
    final igstRate = (item['igst_rate'] as num?) ?? 0;
    final utgstRate = (item['utgst_rate'] as num?) ?? 0;

    return {
      'product_name': item['product_name'],
      'part_number': item['part_number'] ?? '',
      'uqc_code': item['uqc_code'] ?? '',
      'hsn_code': item['hsn_code'] ?? '',
      'quantity': quantity,
      'price': costPrice,
      'cgst_rate': cgstRate,
      'sgst_rate': sgstRate,
      'igst_rate': igstRate,
      'utgst_rate': utgstRate,
      'cgst_amount': item['cgst_amount'],
      'sgst_amount': item['sgst_amount'],
      'igst_amount': item['igst_amount'],
      'utgst_amount': item['utgst_amount'],
      'taxable_amount': item['subtotal'],
      'tax_amount': item['tax_amount'],
      'total': item['total_amount'],
    };
  }).toList();

  final transformedNonTaxableItems = nonTaxableItems.map((item) {
    return {
      'product_name': item['product_name'],
      'part_number': item['part_number'] ?? '',
      'uqc_code': item['uqc_code'] ?? '',
      'hsn_code': item['hsn_code'] ?? '',
      'quantity': item['quantity'],
      'price': item['cost_price'],
      'total': item['total_amount'],
    };
  }).toList();

  // Calculate totals
  final subtotal = debitNote['subtotal'] as num? ?? 0;
  final taxAmount = debitNote['tax_amount'] as num? ?? 0;
  final total = debitNote['total_amount'] as num? ?? 0;

  // Format date as DD-MM-YYYY
  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr.split(' ')[0]);
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  return {
    'debitNote': {
      'debit_note_number': debitNote['debit_note_number'],
      'debit_note_date': formatDate(debitNote['created_at']?.toString()),
      'purchase_number': debitNote['purchase_number'],
      'reason': debitNote['reason'],
      'vendor_name': debitNote['name'],
      'vendor_legal_name': debitNote['legal_name'],
      'vendor_gst_number': debitNote['gst_number'],
      'vendor_phone': debitNote['phone'],
      'vendor_email': debitNote['email'],
      'vendor_address_line1': debitNote['address_line1'],
      'vendor_address_line2': debitNote['address_line2'],
      'vendor_city': debitNote['city'],
      'vendor_state': debitNote['state'],
      'vendor_pincode': debitNote['pincode'],
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
      'max_refundable_amount': debitNote['max_refundable_amount'],
      'refunded_amount': debitNote['refunded_amount'],
      'refund_status': debitNote['refund_status'],
    },
    'taxableItems': transformedTaxableItems,
    'nonTaxableItems': transformedNonTaxableItems,
    'refunds': refunds,
  };
});

class DebitNoteDetailsScreen extends ConsumerWidget {
  final int debitNoteId;

  const DebitNoteDetailsScreen({super.key, required this.debitNoteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debitNoteAsync = ref.watch(debitNoteDetailsProvider(debitNoteId));

    return Scaffold(
      appBar: AppBar(title: const Text('Debit Note Details')),
      body: debitNoteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Debit Note not found'));
          }

          final debitNote = data['debitNote'] as Map<String, dynamic>;
          final taxableItems =
              data['taxableItems'] as List<Map<String, dynamic>>;
          final nonTaxableItems =
              data['nonTaxableItems'] as List<Map<String, dynamic>>;
          final refunds = data['refunds'] as List<Map<String, dynamic>>;

          return Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vendor Details and Refund Status side by side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildVendorDetails(debitNote)),
                      const SizedBox(width: 48),
                      Expanded(
                        child: _buildRefundStatusSection(
                          debitNote,
                          refunds,
                          ref,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Non-Taxable Items Table (if any)
                  if (nonTaxableItems.isNotEmpty) ...[
                    _buildNonTaxableDebitNoteTable(nonTaxableItems),
                    const SizedBox(height: 32),
                  ],

                  // Taxable Items Table (if any)
                  if (taxableItems.isNotEmpty) ...[
                    _buildTaxableDebitNoteTable(taxableItems),
                    const SizedBox(height: 32),
                  ],

                  // Combined Totals Section
                  _buildTotalsSection(debitNote, taxableItems.isNotEmpty),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVendorDetails(Map<String, dynamic> debitNote) {
    final vendorName = debitNote['vendor_name'] as String? ?? 'N/A';
    final vendorLegalName = debitNote['vendor_legal_name'] as String?;
    final vendorGstNumber = debitNote['vendor_gst_number'] as String?;
    final vendorPhone = debitNote['vendor_phone'] as String?;
    final vendorEmail = debitNote['vendor_email'] as String?;
    final addressLine1 = debitNote['vendor_address_line1'] as String?;
    final addressLine2 = debitNote['vendor_address_line2'] as String?;
    final city = debitNote['vendor_city'] as String?;
    final state = debitNote['vendor_state'] as String?;
    final pincode = debitNote['vendor_pincode'] as String?;

    // Build address string
    final addressParts = <String>[];
    if (addressLine1 != null && addressLine1.isNotEmpty) {
      addressParts.add(addressLine1);
    }
    if (addressLine2 != null && addressLine2.isNotEmpty) {
      addressParts.add(addressLine2);
    }
    if (city != null && city.isNotEmpty) addressParts.add(city);
    if (state != null && state.isNotEmpty) addressParts.add(state);
    if (pincode != null && pincode.isNotEmpty) addressParts.add(pincode);
    final address = addressParts.isNotEmpty ? addressParts.join(', ') : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VENDOR DETAILS',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildDetailRow('Vendor Name', vendorName),
        if (vendorLegalName != null && vendorLegalName.isNotEmpty)
          _buildDetailRow('Legal Name', vendorLegalName),
        if (vendorGstNumber != null && vendorGstNumber.isNotEmpty)
          _buildDetailRow('GST Number', vendorGstNumber),
        if (vendorPhone != null && vendorPhone.isNotEmpty)
          _buildDetailRow('Phone', vendorPhone),
        if (vendorEmail != null && vendorEmail.isNotEmpty)
          _buildDetailRow('Email', vendorEmail),
        if (address != null) _buildDetailRow('Address', address),
      ],
    );
  }

  Widget _buildDebitNoteInfo(Map<String, dynamic> debitNote) {
    final debitNoteNumber = debitNote['debit_note_number'] as String? ?? 'N/A';
    final debitNoteDate = debitNote['debit_note_date'] as String? ?? 'N/A';
    final purchaseNumber = debitNote['purchase_number'] as String?;
    final reason = debitNote['reason'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DEBIT NOTE INFORMATION',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildDetailRow('Debit Note Number', 'DN$debitNoteNumber'),
        if (purchaseNumber != null && purchaseNumber.isNotEmpty)
          _buildDetailRow('Purchase Number', purchaseNumber),
        _buildDetailRow('Debit Note Date', debitNoteDate),
        if (reason != null && reason.isNotEmpty)
          _buildDetailRow('Reason', reason),
      ],
    );
  }

  Widget _buildRefundStatusSection(
    Map<String, dynamic> debitNote,
    List<dynamic> refunds,
    WidgetRef ref,
  ) {
    final debitNoteNumber = debitNote['debit_note_number'] as String? ?? 'N/A';
    final debitNoteDate = debitNote['debit_note_date'] as String? ?? 'N/A';
    final purchaseNumber = debitNote['purchase_number'] as String?;
    final reason = debitNote['reason'] as String?;
    final maxRefundable =
        (debitNote['max_refundable_amount'] as num?)?.toDouble() ?? 0.0;
    final refundedAmount =
        (debitNote['refunded_amount'] as num?)?.toDouble() ?? 0.0;
    final refundStatus = debitNote['refund_status'] as String? ?? 'pending';
    final remainingAmount = maxRefundable - refundedAmount;

    // Determine status color, label, and icon
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (refundStatus == 'refunded') {
      statusColor = Colors.green;
      statusLabel = 'Fully Refunded';
      statusIcon = Icons.check_circle;
    } else if (refundStatus == 'partial') {
      statusColor = Colors.orange;
      statusLabel = 'Partially Refunded';
      statusIcon = Icons.access_time;
    } else if (refundStatus == 'adjusted') {
      statusColor = Colors.blue;
      statusLabel = 'Adjusted';
      statusIcon = Icons.balance;
    } else {
      statusColor = Colors.red;
      statusLabel = 'Pending';
      statusIcon = Icons.pending;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DEBIT NOTE INFORMATION',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildDetailRow('Debit Note Number', 'DN$debitNoteNumber'),
        if (purchaseNumber != null && purchaseNumber.isNotEmpty)
          _buildDetailRow('Purchase Number', purchaseNumber),
        _buildDetailRow('Debit Note Date', debitNoteDate),
        if (reason != null && reason.isNotEmpty)
          _buildDetailRow('Reason', reason),
        const SizedBox(height: 12),
        const Text(
          'REFUND STATUS',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildRefundRow('Max Refundable', maxRefundable, Colors.black87),
              if (refundedAmount > 0) ...[
                const SizedBox(height: 4),
                _buildRefundRow(
                  'Refunded Amount',
                  refundedAmount,
                  Colors.green,
                ),
              ],
              if (remainingAmount > 0.01) ...[
                const SizedBox(height: 4),
                _buildRefundRow('Remaining', remainingAmount, Colors.orange),
              ],
              if (refunds.isNotEmpty) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: ref.context,
                      builder: (context) => _RefundHistoryDialog(
                        refunds: refunds.cast<Map<String, dynamic>>(),
                        maxRefundable: maxRefundable,
                        refundedAmount: refundedAmount,
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long),
                  label: Text('View ${refunds.length} Refund(s)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRefundRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: color.withOpacity(0.8)),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildNonTaxableDebitNoteTable(List<Map<String, dynamic>> items) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FixedColumnWidth(60),
        1: FixedColumnWidth(200),
        2: FixedColumnWidth(120),
        3: FixedColumnWidth(80),
        4: FixedColumnWidth(100),
        5: FixedColumnWidth(60),
        6: FixedColumnWidth(120),
        7: FixedColumnWidth(120),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            _buildTableHeader('No.'),
            _buildTableHeader('Product Name'),
            _buildTableHeader('Part Number'),
            _buildTableHeader('UQC'),
            _buildTableHeader('HSN Code'),
            _buildTableHeader('Qty'),
            _buildTableHeader('Rate Per Unit'),
            _buildTableHeader('Total'),
          ],
        ),
        ...items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;
          final productName = item['product_name'] as String? ?? '';
          final partNumber = item['part_number'] as String? ?? '';
          final uqcCode = item['uqc_code'] as String? ?? '';
          final hsnCode = item['hsn_code'] as String? ?? '';
          final quantity = item['quantity'] as num? ?? 0;
          final price = item['price'] as num? ?? 0;
          final total = item['total'] as num? ?? 0;

          return TableRow(
            children: [
              _buildTableCell(index.toString()),
              _buildTableCell(productName),
              _buildTableCell(partNumber),
              _buildTableCell(uqcCode),
              _buildTableCell(hsnCode),
              _buildTableCell(quantity.toString()),
              _buildTableCell(price.toStringAsFixed(2)),
              _buildTableCell(total.toStringAsFixed(2)),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTaxableDebitNoteTable(List<Map<String, dynamic>> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade300),
        columnWidths: const {
          0: FixedColumnWidth(60),
          1: FixedColumnWidth(180),
          2: FixedColumnWidth(120),
          3: FixedColumnWidth(80),
          4: FixedColumnWidth(100),
          5: FixedColumnWidth(60),
          6: FixedColumnWidth(120),
          7: FixedColumnWidth(100),
          8: FixedColumnWidth(100),
          9: FixedColumnWidth(80),
          10: FixedColumnWidth(80),
          11: FixedColumnWidth(80),
          12: FixedColumnWidth(80),
          13: FixedColumnWidth(100),
          14: FixedColumnWidth(100),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade100),
            children: [
              _buildTableHeader('No.'),
              _buildTableHeader('Product Name'),
              _buildTableHeader('Part Number'),
              _buildTableHeader('UQC'),
              _buildTableHeader('HSN Code'),
              _buildTableHeader('Qty'),
              _buildTableHeader('Rate Per Unit'),
              _buildTableHeader('Value'),
              _buildTableHeader('Taxable Amt'),
              _buildTableHeader('CGST%'),
              _buildTableHeader('SGST%'),
              _buildTableHeader('IGST/UTGST%'),
              _buildTableHeader('CESS%'),
              _buildTableHeader('Tax Amt'),
              _buildTableHeader('Total'),
            ],
          ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final item = entry.value;
            final productName = item['product_name'] as String? ?? '';
            final partNumber = item['part_number'] as String? ?? '';
            final uqcCode = item['uqc_code'] as String? ?? '';
            final hsnCode = item['hsn_code'] as String? ?? '';
            final quantity = item['quantity'] as num? ?? 0;
            final price = item['price'] as num? ?? 0;
            final cgstRate = item['cgst_rate'] as num? ?? 0;
            final sgstRate = item['sgst_rate'] as num? ?? 0;
            final igstRate = item['igst_rate'] as num? ?? 0;
            final utgstRate = item['utgst_rate'] as num? ?? 0;
            final taxableAmount = item['taxable_amount'] as num? ?? 0;
            final taxAmount = item['tax_amount'] as num? ?? 0;
            final total = item['total'] as num? ?? 0;

            // Calculate Value (Qty * Rate Per Unit)
            final value = quantity * price;

            return TableRow(
              children: [
                _buildTableCell(index.toString()),
                _buildTableCell(productName),
                _buildTableCell(partNumber),
                _buildTableCell(uqcCode),
                _buildTableCell(hsnCode),
                _buildTableCell(quantity.toString()),
                _buildTableCell(price.toStringAsFixed(2)),
                _buildTableCell(value.toStringAsFixed(2)),
                _buildTableCell(taxableAmount.toStringAsFixed(2)),
                _buildTableCell(cgstRate.toStringAsFixed(2)),
                _buildTableCell(sgstRate.toStringAsFixed(2)),
                _buildTableCell(igstRate.toStringAsFixed(2)),
                _buildTableCell(utgstRate.toStringAsFixed(2)),
                _buildTableCell(taxAmount.toStringAsFixed(2)),
                _buildTableCell(total.toStringAsFixed(2)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTotalsSection(
    Map<String, dynamic> debitNote,
    bool hasTaxableItems,
  ) {
    final subtotal = (debitNote['subtotal'] as num?) ?? 0;
    final taxAmount = (debitNote['tax_amount'] as num?) ?? 0;
    final total = (debitNote['total'] as num?) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(thickness: 2),
        const SizedBox(height: 16),
        _buildTotalRow('Subtotal', subtotal),
        if (hasTaxableItems) _buildTotalRow('Tax Amount', taxAmount),
        const SizedBox(height: 8),
        _buildTotalRow('Total Amount', total, isBold: true),
      ],
    );
  }

  Widget _buildTotalRow(String label, num amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isBold ? 16 : 14,
              ),
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefundHistoryDialog extends StatelessWidget {
  final List<Map<String, dynamic>> refunds;
  final double maxRefundable;
  final double refundedAmount;

  const _RefundHistoryDialog({
    required this.refunds,
    required this.maxRefundable,
    required this.refundedAmount,
  });

  @override
  Widget build(BuildContext context) {
    final remainingAmount = maxRefundable - refundedAmount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.history, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Refund History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${refunds.length} refund(s)',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Refund Summary
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Max Refundable',
                    '₹${maxRefundable.toStringAsFixed(2)}',
                    AppColors.textPrimary,
                  ),
                  const Divider(height: 16),
                  _buildSummaryRow(
                    'Total Refunded',
                    '₹${refundedAmount.toStringAsFixed(2)}',
                    Colors.green,
                  ),
                  const Divider(height: 16),
                  _buildSummaryRow(
                    'Remaining',
                    '₹${remainingAmount.toStringAsFixed(2)}',
                    remainingAmount > 0 ? Colors.orange : Colors.green,
                    bold: true,
                  ),
                ],
              ),
            ),

            // Refunds List
            Expanded(
              child: refunds.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 64,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No refunds yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: refunds.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final refund = refunds[index];
                        return _buildRefundItem(refund);
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String amount,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRefundItem(Map<String, dynamic> refund) {
    final amount = (refund['amount'] as num).toDouble();
    final refundMethod = refund['refund_method'] as String;
    final refundDate = DateTime.parse(refund['refund_date'] as String);
    final notes = refund['notes'] as String?;

    // Refund method icon and label
    IconData methodIcon;
    String methodLabel;

    switch (refundMethod) {
      case 'cash':
        methodIcon = Icons.money;
        methodLabel = 'Cash';
        break;
      case 'upi':
        methodIcon = Icons.qr_code;
        methodLabel = 'UPI';
        break;
      case 'card':
        methodIcon = Icons.credit_card;
        methodLabel = 'Card';
        break;
      case 'bank_transfer':
        methodIcon = Icons.account_balance;
        methodLabel = 'Bank Transfer';
        break;
      case 'cheque':
        methodIcon = Icons.receipt_long;
        methodLabel = 'Cheque';
        break;
      default:
        methodIcon = Icons.currency_rupee;
        methodLabel = 'Other';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Refund icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(methodIcon, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),

          // Refund details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      methodLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${refundDate.day.toString().padLeft(2, '0')}/${refundDate.month.toString().padLeft(2, '0')}/${refundDate.year} at ${refundDate.hour.toString().padLeft(2, '0')}:${refundDate.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
