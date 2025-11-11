import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';

// Provider for debit note details
final debitNoteDetailsProvider = FutureProvider.family<Map<String, dynamic>?, int>((
  ref,
  debitNoteId,
) async {
  final db = await ref.watch(databaseProvider);

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
    },
    'taxableItems': transformedTaxableItems,
    'nonTaxableItems': transformedNonTaxableItems,
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

          return Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vendor Details and Debit Note Information side by side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildVendorDetails(debitNote)),
                      const SizedBox(width: 48),
                      Expanded(child: _buildDebitNoteInfo(debitNote)),
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
