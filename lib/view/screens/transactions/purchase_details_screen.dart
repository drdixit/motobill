import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';
import '../../../repository/purchase_repository.dart';

// Provider for purchase details
final purchaseDetailsProvider = FutureProvider.family<Map<String, dynamic>?, int>((
  ref,
  purchaseId,
) async {
  final db = await ref.watch(databaseProvider);
  final repository = PurchaseRepository(db);

  final purchase = await repository.getPurchaseById(purchaseId);
  if (purchase == null) return null;

  final items = await repository.getPurchaseItems(purchaseId);

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
  final subtotal = purchase['subtotal'] as num? ?? 0;
  final taxAmount = purchase['tax_amount'] as num? ?? 0;
  final total = purchase['total_amount'] as num? ?? 0;

  // Fetch debit notes associated with this purchase
  final debitNotesResult = await db.rawQuery(
    '''
    SELECT id, debit_note_number, reason, subtotal, tax_amount, total_amount
    FROM debit_notes
    WHERE purchase_id = ? AND is_deleted = 0
    ORDER BY created_at DESC
    ''',
    [purchaseId],
  );

  // Fetch items for each debit note
  final debitNotesWithItems = <Map<String, dynamic>>[];
  for (final debitNote in debitNotesResult) {
    final debitNoteId = debitNote['id'] as int;
    final items = await db.rawQuery(
      '''
      SELECT product_name, part_number, uqc_code, hsn_code, quantity,
             cost_price, subtotal, cgst_rate, sgst_rate, igst_rate, utgst_rate,
             cgst_amount, sgst_amount, igst_amount, utgst_amount,
             tax_amount, total_amount
      FROM debit_note_items
      WHERE debit_note_id = ? AND is_deleted = 0
      ORDER BY id
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

    // Transform items to match table format
    final transformedTaxable = taxableItems.map((item) {
      return {
        'product_name': item['product_name'],
        'part_number': item['part_number'] ?? '',
        'uqc_code': item['uqc_code'] ?? '',
        'hsn_code': item['hsn_code'] ?? '',
        'quantity': item['quantity'],
        'price': item['cost_price'],
        'cgst_rate': item['cgst_rate'],
        'sgst_rate': item['sgst_rate'],
        'igst_rate': item['igst_rate'],
        'utgst_rate': item['utgst_rate'],
        'taxable_amount': item['subtotal'],
        'tax_amount': item['tax_amount'],
        'total': item['total_amount'],
      };
    }).toList();

    final transformedNonTaxable = nonTaxableItems.map((item) {
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

    debitNotesWithItems.add({
      'debit_note_number': debitNote['debit_note_number'],
      'reason': debitNote['reason'],
      'subtotal': debitNote['subtotal'],
      'tax_amount': debitNote['tax_amount'],
      'total': debitNote['total_amount'],
      'taxableItems': transformedTaxable,
      'nonTaxableItems': transformedNonTaxable,
    });
  }

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
    'purchase': {
      'purchase_number': purchase['purchase_number'],
      'reference_number': purchase['purchase_reference_number'],
      'purchase_date': formatDate(purchase['created_at']?.toString()),
      'vendor_name': purchase['vendor_name'],
      'vendor_legal_name': purchase['vendor_legal_name'],
      'vendor_gst': purchase['vendor_gst'],
      'vendor_phone': purchase['vendor_phone'],
      'vendor_email': purchase['vendor_email'],
      'vendor_address_line1': purchase['vendor_address_line1'],
      'vendor_address_line2': purchase['vendor_address_line2'],
      'vendor_city': purchase['vendor_city'],
      'vendor_state': purchase['vendor_state'],
      'vendor_pincode': purchase['vendor_pincode'],
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
    },
    'taxableItems': transformedTaxableItems,
    'nonTaxableItems': transformedNonTaxableItems,
    'debitNotes': debitNotesWithItems,
  };
});

class PurchaseDetailsScreen extends ConsumerWidget {
  final int purchaseId;

  const PurchaseDetailsScreen({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchaseAsync = ref.watch(purchaseDetailsProvider(purchaseId));

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Details')),
      body: purchaseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Purchase not found'));
          }

          final purchase = data['purchase'] as Map<String, dynamic>;
          final taxableItems =
              data['taxableItems'] as List<Map<String, dynamic>>;
          final nonTaxableItems =
              data['nonTaxableItems'] as List<Map<String, dynamic>>;
          final debitNotes = data['debitNotes'] as List<Map<String, dynamic>>;

          return Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vendor Details and Purchase Information side by side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildVendorDetails(purchase)),
                      const SizedBox(width: 48),
                      Expanded(child: _buildPurchaseInfo(purchase)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Non-Taxable Items Table (if any)
                  if (nonTaxableItems.isNotEmpty) ...[
                    _buildNonTaxablePurchaseTable(nonTaxableItems),
                    const SizedBox(height: 32),
                  ],

                  // Taxable Items Table (if any)
                  if (taxableItems.isNotEmpty) ...[
                    _buildTaxablePurchaseTable(taxableItems),
                    const SizedBox(height: 32),
                  ],

                  // Combined Totals Section
                  _buildTotalsSection(purchase, taxableItems.isNotEmpty),

                  // Debit Notes Section (if any)
                  if (debitNotes.isNotEmpty)
                    ..._buildDebitNotesSection(debitNotes),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVendorDetails(Map<String, dynamic> purchase) {
    final vendorName = purchase['vendor_name'] as String? ?? 'N/A';
    final vendorLegalName = purchase['vendor_legal_name'] as String?;
    final vendorGst = purchase['vendor_gst'] as String?;
    final vendorPhone = purchase['vendor_phone'] as String?;
    final vendorEmail = purchase['vendor_email'] as String?;
    final addressLine1 = purchase['vendor_address_line1'] as String?;
    final addressLine2 = purchase['vendor_address_line2'] as String?;
    final city = purchase['vendor_city'] as String?;
    final state = purchase['vendor_state'] as String?;
    final pincode = purchase['vendor_pincode'] as String?;

    // Build address string
    final addressParts = <String>[];
    if (addressLine1 != null && addressLine1.isNotEmpty)
      addressParts.add(addressLine1);
    if (addressLine2 != null && addressLine2.isNotEmpty)
      addressParts.add(addressLine2);
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
        if (vendorGst != null && vendorGst.isNotEmpty)
          _buildDetailRow('GST Number', vendorGst),
        if (vendorPhone != null && vendorPhone.isNotEmpty)
          _buildDetailRow('Phone', vendorPhone),
        if (vendorEmail != null && vendorEmail.isNotEmpty)
          _buildDetailRow('Email', vendorEmail),
        if (address != null) _buildDetailRow('Address', address),
      ],
    );
  }

  Widget _buildPurchaseInfo(Map<String, dynamic> purchase) {
    final purchaseNumber = purchase['purchase_number'] as String? ?? 'N/A';
    final referenceNumber = purchase['reference_number'] as String?;
    final purchaseDate = purchase['purchase_date'] as String? ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PURCHASE INFORMATION',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildDetailRow('Purchase Number', purchaseNumber),
        if (referenceNumber != null && referenceNumber.isNotEmpty)
          _buildDetailRow('Reference Number', referenceNumber),
        _buildDetailRow('Purchase Date', purchaseDate),
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
            width: 160,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxablePurchaseTable(List<Map<String, dynamic>> items) {
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
              _buildTableHeader('IGST%'),
              _buildTableHeader('UTGST%'),
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

  Widget _buildNonTaxablePurchaseTable(List<Map<String, dynamic>> items) {
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
    Map<String, dynamic> purchase,
    bool hasTaxableItems,
  ) {
    final subtotal = purchase['subtotal'] as num? ?? 0;
    final taxAmount = purchase['tax_amount'] as num? ?? 0;
    final total = purchase['total'] as num? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 120,
              child: Text(
                'Subtotal:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 16),
            Text('₹${subtotal.toStringAsFixed(2)}'),
          ],
        ),
        if (hasTaxableItems && taxAmount > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(
                width: 120,
                child: Text(
                  'Tax:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 16),
              Text('₹${taxAmount.toStringAsFixed(2)}'),
            ],
          ),
        ],
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: SizedBox(width: 200, child: Divider()),
        ),
        Row(
          children: [
            const SizedBox(
              width: 120,
              child: Text(
                'Total:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '₹${total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildDebitNotesSection(List<Map<String, dynamic>> debitNotes) {
    final widgets = <Widget>[];

    for (final debitNote in debitNotes) {
      final debitNoteNumber = debitNote['debit_note_number'] as String;
      final taxableItems =
          debitNote['taxableItems'] as List<Map<String, dynamic>>;
      final nonTaxableItems =
          debitNote['nonTaxableItems'] as List<Map<String, dynamic>>;

      widgets.addAll([
        const SizedBox(height: 32),
        const Divider(thickness: 2),
        const SizedBox(height: 16),
        Text(
          'DN$debitNoteNumber',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Non-Taxable Items Table (if any)
        if (nonTaxableItems.isNotEmpty) ...[
          _buildNonTaxablePurchaseTable(nonTaxableItems),
          const SizedBox(height: 16),
        ],

        // Taxable Items Table (if any)
        if (taxableItems.isNotEmpty) ...[
          _buildTaxablePurchaseTable(taxableItems),
          const SizedBox(height: 16),
        ],
      ]);
    }

    return widgets;
  }
}
