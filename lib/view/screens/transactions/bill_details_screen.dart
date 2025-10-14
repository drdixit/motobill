import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';
import '../../../repository/bill_repository.dart';

// Provider for bill details
final billDetailsProvider = FutureProvider.family<Map<String, dynamic>?, int>((
  ref,
  billId,
) async {
  final db = await ref.watch(databaseProvider);
  final repository = BillRepository(db);

  final bill = await repository.getBillById(billId);
  if (bill == null) return null;

  final items = await repository.getBillItems(billId);

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
    final sellingPrice = (item['selling_price'] as num?) ?? 0;
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
      'price': sellingPrice,
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
      'price': item['selling_price'],
      'total': item['total_amount'],
    };
  }).toList();

  // Calculate totals
  final subtotal = bill['subtotal'] as num? ?? 0;
  final taxAmount = bill['tax_amount'] as num? ?? 0;
  final total = bill['total_amount'] as num? ?? 0;

  // Fetch credit notes associated with this bill
  final creditNotesResult = await db.rawQuery(
    '''
    SELECT id, credit_note_number, reason, subtotal, tax_amount, total_amount
    FROM credit_notes
    WHERE bill_id = ? AND is_deleted = 0
    ORDER BY created_at DESC
    ''',
    [billId],
  );

  // Fetch items for each credit note
  final creditNotesWithItems = <Map<String, dynamic>>[];
  for (final creditNote in creditNotesResult) {
    final creditNoteId = creditNote['id'] as int;
    final items = await db.rawQuery(
      '''
      SELECT product_name, part_number, uqc_code, hsn_code, quantity,
             selling_price, subtotal, cgst_rate, sgst_rate, igst_rate, utgst_rate,
             cgst_amount, sgst_amount, igst_amount, utgst_amount,
             tax_amount, total_amount
      FROM credit_note_items
      WHERE credit_note_id = ? AND is_deleted = 0
      ORDER BY id
      ''',
      [creditNoteId],
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
        'price': item['selling_price'],
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
        'price': item['selling_price'],
        'total': item['total_amount'],
      };
    }).toList();

    creditNotesWithItems.add({
      'credit_note_number': creditNote['credit_note_number'],
      'reason': creditNote['reason'],
      'subtotal': creditNote['subtotal'],
      'tax_amount': creditNote['tax_amount'],
      'total': creditNote['total_amount'],
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
    'bill': {
      'bill_number': bill['bill_number'],
      'bill_date': formatDate(bill['created_at']?.toString()),
      'customer_name': bill['customer_name'],
      'customer_legal_name': bill['customer_legal_name'],
      'customer_gst_number': bill['customer_gst_number'],
      'customer_phone': bill['customer_phone'],
      'customer_email': bill['customer_email'],
      'customer_address_line1': bill['customer_address_line1'],
      'customer_address_line2': bill['customer_address_line2'],
      'customer_city': bill['customer_city'],
      'customer_state': bill['customer_state'],
      'customer_pincode': bill['customer_pincode'],
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
    },
    'taxableItems': transformedTaxableItems,
    'nonTaxableItems': transformedNonTaxableItems,
    'creditNotes': creditNotesWithItems,
  };
});

class BillDetailsScreen extends ConsumerWidget {
  final int billId;

  const BillDetailsScreen({super.key, required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billAsync = ref.watch(billDetailsProvider(billId));

    return Scaffold(
      appBar: AppBar(title: const Text('Bill Details')),
      body: billAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Bill not found'));
          }

          final bill = data['bill'] as Map<String, dynamic>;
          final taxableItems =
              data['taxableItems'] as List<Map<String, dynamic>>;
          final nonTaxableItems =
              data['nonTaxableItems'] as List<Map<String, dynamic>>;
          final creditNotes = data['creditNotes'] as List<Map<String, dynamic>>;

          return Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Details and Bill Information side by side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildCustomerDetails(bill)),
                      const SizedBox(width: 48),
                      Expanded(child: _buildBillInfo(bill)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Non-Taxable Items Table (if any)
                  if (nonTaxableItems.isNotEmpty) ...[
                    _buildNonTaxableBillTable(
                      nonTaxableItems,
                      bill['bill_number'] as String? ?? '',
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Taxable Items Table (if any)
                  if (taxableItems.isNotEmpty) ...[
                    _buildTaxableBillTable(
                      taxableItems,
                      bill['bill_number'] as String? ?? '',
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Combined Totals Section
                  _buildTotalsSection(bill, taxableItems.isNotEmpty),

                  // Credit Notes Section (if any)
                  if (creditNotes.isNotEmpty)
                    ..._buildCreditNotesSection(creditNotes),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomerDetails(Map<String, dynamic> bill) {
    final customerName = bill['customer_name'] as String? ?? 'N/A';
    final customerLegalName = bill['customer_legal_name'] as String?;
    final customerGstNumber = bill['customer_gst_number'] as String?;
    final customerPhone = bill['customer_phone'] as String?;
    final customerEmail = bill['customer_email'] as String?;
    final addressLine1 = bill['customer_address_line1'] as String?;
    final addressLine2 = bill['customer_address_line2'] as String?;
    final city = bill['customer_city'] as String?;
    final state = bill['customer_state'] as String?;
    final pincode = bill['customer_pincode'] as String?;

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
          'CUSTOMER DETAILS',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildDetailRow('Customer Name', customerName),
        if (customerLegalName != null && customerLegalName.isNotEmpty)
          _buildDetailRow('Legal Name', customerLegalName),
        if (customerGstNumber != null && customerGstNumber.isNotEmpty)
          _buildDetailRow('GST Number', customerGstNumber),
        if (customerPhone != null && customerPhone.isNotEmpty)
          _buildDetailRow('Phone', customerPhone),
        if (customerEmail != null && customerEmail.isNotEmpty)
          _buildDetailRow('Email', customerEmail),
        if (address != null) _buildDetailRow('Address', address),
      ],
    );
  }

  Widget _buildBillInfo(Map<String, dynamic> bill) {
    final billNumber = bill['bill_number'] as String? ?? 'N/A';
    final billDate = bill['bill_date'] as String? ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BILL INFORMATION',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildDetailRow('Bill Number', billNumber),
        _buildDetailRow('Bill Date', billDate),
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

  Widget _buildTaxableBillTable(
    List<Map<String, dynamic>> items,
    String billNumber,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I$billNumber',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
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
        ),
      ],
    );
  }

  Widget _buildNonTaxableBillTable(
    List<Map<String, dynamic>> items,
    String billNumber,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'E$billNumber',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Table(
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
        ),
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

  Widget _buildTotalsSection(Map<String, dynamic> bill, bool hasTaxableItems) {
    final subtotal = bill['subtotal'] as num? ?? 0;
    final taxAmount = bill['tax_amount'] as num? ?? 0;
    final total = bill['total'] as num? ?? 0;

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

  List<Widget> _buildCreditNotesSection(
    List<Map<String, dynamic>> creditNotes,
  ) {
    final widgets = <Widget>[];

    for (final creditNote in creditNotes) {
      final creditNoteNumber = creditNote['credit_note_number'] as String;
      final total = (creditNote['total'] as num?) ?? 0;
      final taxableItems =
          creditNote['taxableItems'] as List<Map<String, dynamic>>;
      final nonTaxableItems =
          creditNote['nonTaxableItems'] as List<Map<String, dynamic>>;

      widgets.addAll([
        const SizedBox(height: 32),
        const Divider(thickness: 2),
        const SizedBox(height: 16),
        Text(
          'CN$creditNoteNumber - ₹${total.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Non-Taxable Items Table (if any)
        if (nonTaxableItems.isNotEmpty) ...[
          _buildNonTaxableBillTable(nonTaxableItems, creditNoteNumber),
          const SizedBox(height: 16),
        ],

        // Taxable Items Table (if any)
        if (taxableItems.isNotEmpty) ...[
          _buildTaxableBillTable(taxableItems, creditNoteNumber),
          const SizedBox(height: 16),
        ],
      ]);
    }

    return widgets;
  }
}
