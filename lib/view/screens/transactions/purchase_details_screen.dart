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

          return Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vendor Details Section
                  _buildVendorDetails(purchase),
                  const SizedBox(height: 24),

                  // Purchase Information Section
                  _buildPurchaseInfo(purchase),
                  const SizedBox(height: 32),

                  // Non-Taxable Items Table (if any)
                  if (nonTaxableItems.isNotEmpty) ...[
                    const Text(
                      'NON-TAXABLE ITEMS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNonTaxablePurchaseTable(nonTaxableItems),
                    const SizedBox(height: 32),
                  ],

                  // Taxable Items Table (if any)
                  if (taxableItems.isNotEmpty) ...[
                    const Text(
                      'TAXABLE ITEMS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTaxablePurchaseTable(taxableItems),
                    const SizedBox(height: 32),
                  ],

                  // Combined Totals Section
                  _buildTotalsSection(purchase, taxableItems.isNotEmpty),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              border: TableBorder.all(color: Colors.grey.shade300),
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
              columns: const [
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('HSN')),
                DataColumn(label: Text('Quantity')),
                DataColumn(label: Text('Price'), numeric: true),
                DataColumn(label: Text('CGST%'), numeric: true),
                DataColumn(label: Text('SGST%'), numeric: true),
                DataColumn(label: Text('IGST%'), numeric: true),
                DataColumn(label: Text('UTGST%'), numeric: true),
                DataColumn(label: Text('Taxable Amt'), numeric: true),
                DataColumn(label: Text('Tax Amt'), numeric: true),
                DataColumn(label: Text('Total'), numeric: true),
              ],
              rows: items.map((item) {
                final productName = item['product_name'] as String? ?? 'N/A';
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

                return DataRow(
                  cells: [
                    DataCell(Text(productName)),
                    DataCell(Text(hsnCode)),
                    DataCell(Text(quantity.toString())),
                    DataCell(Text('₹${price.toStringAsFixed(2)}')),
                    DataCell(
                      Text(cgstRate > 0 ? cgstRate.toStringAsFixed(1) : '-'),
                    ),
                    DataCell(
                      Text(sgstRate > 0 ? sgstRate.toStringAsFixed(1) : '-'),
                    ),
                    DataCell(
                      Text(igstRate > 0 ? igstRate.toStringAsFixed(1) : '-'),
                    ),
                    DataCell(
                      Text(utgstRate > 0 ? utgstRate.toStringAsFixed(1) : '-'),
                    ),
                    DataCell(Text('₹${taxableAmount.toStringAsFixed(2)}')),
                    DataCell(Text('₹${taxAmount.toStringAsFixed(2)}')),
                    DataCell(Text('₹${total.toStringAsFixed(2)}')),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNonTaxablePurchaseTable(List<Map<String, dynamic>> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              border: TableBorder.all(color: Colors.grey.shade300),
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
              columns: const [
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('HSN')),
                DataColumn(label: Text('Quantity')),
                DataColumn(label: Text('Price'), numeric: true),
                DataColumn(label: Text('Total'), numeric: true),
              ],
              rows: items.map((item) {
                final productName = item['product_name'] as String? ?? 'N/A';
                final hsnCode = item['hsn_code'] as String? ?? '';
                final quantity = item['quantity'] as num? ?? 0;
                final price = item['price'] as num? ?? 0;
                final total = item['total'] as num? ?? 0;

                return DataRow(
                  cells: [
                    DataCell(Text(productName)),
                    DataCell(Text(hsnCode)),
                    DataCell(Text(quantity.toString())),
                    DataCell(Text('₹${price.toStringAsFixed(2)}')),
                    DataCell(Text('₹${total.toStringAsFixed(2)}')),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'Subtotal:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 120,
              child: Text(
                '₹${subtotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        if (hasTaxableItems && taxAmount > 0) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Tax:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 16),
              SizedBox(
                width: 120,
                child: Text(
                  '₹${taxAmount.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: SizedBox(width: 200, child: Divider()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'Total:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 120,
              child: Text(
                '₹${total.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
