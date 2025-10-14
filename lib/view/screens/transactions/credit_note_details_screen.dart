import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';

// Provider for credit note details
final creditNoteDetailsProvider =
    FutureProvider.family<Map<String, dynamic>?, int>((
      ref,
      creditNoteId,
    ) async {
      final db = await ref.watch(databaseProvider);

      // Get credit note details
      final creditNoteResult = await db.rawQuery(
        '''SELECT cn.*,
       c.name as customer_name,
       c.legal_name as customer_legal_name,
       c.gst_number as customer_gst_number,
       c.phone as customer_phone,
       c.email as customer_email,
       c.address_line1 as customer_address_line1,
       c.address_line2 as customer_address_line2,
       c.city as customer_city,
       c.state as customer_state,
       c.pincode as customer_pincode,
       b.bill_number as bill_number
    FROM credit_notes cn
    LEFT JOIN customers c ON cn.customer_id = c.id
    LEFT JOIN bills b ON cn.bill_id = b.id
    WHERE cn.id = ? AND cn.is_deleted = 0''',
        [creditNoteId],
      );

      if (creditNoteResult.isEmpty) return null;
      final creditNote = creditNoteResult.first;

      // Get credit note items
      final items = await db.rawQuery(
        '''SELECT * FROM credit_note_items
    WHERE credit_note_id = ? AND is_deleted = 0
    ORDER BY id''',
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
        return cgstRate == 0 &&
            sgstRate == 0 &&
            igstRate == 0 &&
            utgstRate == 0;
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
      final subtotal = creditNote['subtotal'] as num? ?? 0;
      final taxAmount = creditNote['tax_amount'] as num? ?? 0;
      final total = creditNote['total_amount'] as num? ?? 0;

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
        'creditNote': {
          'credit_note_number': creditNote['credit_note_number'],
          'bill_number': creditNote['bill_number'],
          'credit_note_date': formatDate(creditNote['created_at']?.toString()),
          'reason': creditNote['reason'] ?? '',
          'customer_name': creditNote['customer_name'],
          'customer_legal_name': creditNote['customer_legal_name'],
          'customer_gst_number': creditNote['customer_gst_number'],
          'customer_phone': creditNote['customer_phone'],
          'customer_email': creditNote['customer_email'],
          'customer_address_line1': creditNote['customer_address_line1'],
          'customer_address_line2': creditNote['customer_address_line2'],
          'customer_city': creditNote['customer_city'],
          'customer_state': creditNote['customer_state'],
          'customer_pincode': creditNote['customer_pincode'],
          'subtotal': subtotal,
          'tax_amount': taxAmount,
          'total': total,
        },
        'taxableItems': transformedTaxableItems,
        'nonTaxableItems': transformedNonTaxableItems,
      };
    });

class CreditNoteDetailsScreen extends ConsumerWidget {
  final int creditNoteId;

  const CreditNoteDetailsScreen({super.key, required this.creditNoteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditNoteAsync = ref.watch(creditNoteDetailsProvider(creditNoteId));

    return Scaffold(
      appBar: AppBar(title: const Text('Credit Note Details')),
      body: creditNoteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Credit Note not found'));
          }

          final creditNote = data['creditNote'] as Map<String, dynamic>;
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
                  // Customer Details and Credit Note Information side by side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildCustomerDetails(creditNote)),
                      const SizedBox(width: 48),
                      Expanded(child: _buildCreditNoteInfo(creditNote)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Non-Taxable Items Table (if any)
                  if (nonTaxableItems.isNotEmpty) ...[
                    _buildNonTaxableCreditNoteTable(nonTaxableItems),
                    const SizedBox(height: 32),
                  ],

                  // Taxable Items Table (if any)
                  if (taxableItems.isNotEmpty) ...[
                    _buildTaxableCreditNoteTable(taxableItems),
                    const SizedBox(height: 32),
                  ],

                  // Combined Totals Section
                  _buildTotalsSection(creditNote, taxableItems.isNotEmpty),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomerDetails(Map<String, dynamic> creditNote) {
    final customerName = creditNote['customer_name'] as String? ?? 'N/A';
    final customerLegalName = creditNote['customer_legal_name'] as String?;
    final customerGstNumber = creditNote['customer_gst_number'] as String?;
    final customerPhone = creditNote['customer_phone'] as String?;
    final customerEmail = creditNote['customer_email'] as String?;
    final addressLine1 = creditNote['customer_address_line1'] as String?;
    final addressLine2 = creditNote['customer_address_line2'] as String?;
    final city = creditNote['customer_city'] as String?;
    final state = creditNote['customer_state'] as String?;
    final pincode = creditNote['customer_pincode'] as String?;

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

  Widget _buildCreditNoteInfo(Map<String, dynamic> creditNote) {
    final creditNoteNumber =
        creditNote['credit_note_number'] as String? ?? 'N/A';
    final billNumber = creditNote['bill_number'] as String?;
    final creditNoteDate = creditNote['credit_note_date'] as String? ?? 'N/A';
    final reason = creditNote['reason'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CREDIT NOTE INFORMATION',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildDetailRow('Credit Note Number', creditNoteNumber),
        if (billNumber != null && billNumber.isNotEmpty)
          _buildDetailRow('Original Bill Number', billNumber),
        _buildDetailRow('Credit Note Date', creditNoteDate),
        if (reason.isNotEmpty) _buildDetailRow('Reason', reason),
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

  Widget _buildTaxableCreditNoteTable(List<Map<String, dynamic>> items) {
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

  Widget _buildNonTaxableCreditNoteTable(List<Map<String, dynamic>> items) {
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
    Map<String, dynamic> creditNote,
    bool hasTaxableItems,
  ) {
    final subtotal = creditNote['subtotal'] as num? ?? 0;
    final taxAmount = creditNote['tax_amount'] as num? ?? 0;
    final total = creditNote['total'] as num? ?? 0;

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
}
