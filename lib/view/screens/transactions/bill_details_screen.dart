import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/database_provider.dart';
import '../../../repository/bill_repository.dart';

// Provider for bill details
final billDetailsProvider = FutureProvider.family<Map<String, dynamic>?, int>((
  ref,
  billId,
) async {
  final db = await ref.watch(databaseProvider);
  final repository = BillRepository(db);
  return repository.getBillById(billId);
});

// Provider for bill items
final billItemsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, billId) async {
      final db = await ref.watch(databaseProvider);
      final repository = BillRepository(db);
      return repository.getBillItems(billId);
    });

class BillDetailsScreen extends ConsumerWidget {
  final int billId;

  const BillDetailsScreen({super.key, required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billAsync = ref.watch(billDetailsProvider(billId));
    final itemsAsync = ref.watch(billItemsProvider(billId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bill Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: billAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (bill) {
          if (bill == null) {
            return const Center(child: Text('Bill not found'));
          }

          return itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
            data: (items) {
              // Split items into taxable and non-taxable
              final taxableItems = items.where((item) {
                final totalGst =
                    (item['cgst_rate'] as num).toDouble() +
                    (item['sgst_rate'] as num).toDouble() +
                    (item['igst_rate'] as num).toDouble() +
                    (item['utgst_rate'] as num).toDouble();
                return totalGst > 0;
              }).toList();

              final nonTaxableItems = items.where((item) {
                final totalGst =
                    (item['cgst_rate'] as num).toDouble() +
                    (item['sgst_rate'] as num).toDouble() +
                    (item['igst_rate'] as num).toDouble() +
                    (item['utgst_rate'] as num).toDouble();
                return totalGst == 0;
              }).toList();

              final hasTaxable = taxableItems.isNotEmpty;
              final hasNonTaxable = nonTaxableItems.isNotEmpty;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Show Invoice (I prefix) if has taxable items
                    if (hasTaxable)
                      _buildBillSection(
                        context,
                        bill,
                        taxableItems,
                        isInvoice: true,
                      ),

                    // Add spacing if both types exist
                    if (hasTaxable && hasNonTaxable) const SizedBox(height: 24),

                    // Show Estimate (E prefix) if has non-taxable items
                    if (hasNonTaxable)
                      _buildBillSection(
                        context,
                        bill,
                        nonTaxableItems,
                        isInvoice: false,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBillSection(
    BuildContext context,
    Map<String, dynamic> bill,
    List<Map<String, dynamic>> items, {
    required bool isInvoice,
  }) {
    final billNumber = bill['bill_number'] as String;
    final displayNumber = isInvoice ? 'I$billNumber' : 'E$billNumber';
    final sectionTitle = isInvoice ? 'Invoice' : 'Estimate';
    final customerName = bill['customer_name'] as String? ?? 'Unknown Customer';
    final createdAt = DateTime.parse(bill['created_at'] as String);

    // Calculate totals for this section
    double subtotal = 0.0;
    double totalTax = 0.0;

    for (var item in items) {
      subtotal += (item['subtotal'] as num).toDouble();
      totalTax += (item['tax_amount'] as num).toDouble();
    }

    final grandTotal = subtotal + totalTax;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isInvoice
                        ? Colors.blue.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    sectionTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isInvoice
                          ? Colors.blue.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  displayNumber,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Customer Info
            _buildInfoRow('Customer', customerName),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Date',
              '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
            ),
            const SizedBox(height: 20),

            // Items Table
            if (isInvoice)
              _buildInvoiceTable(items)
            else
              _buildEstimateTable(items),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Totals
            _buildTotalRow('Subtotal', subtotal),
            if (isInvoice) ...[
              const SizedBox(height: 8),
              _buildTotalRow('Tax', totalTax, color: Colors.orange.shade700),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Grand Total',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '₹${grandTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildInvoiceTable(List<Map<String, dynamic>> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        horizontalMargin: 8,
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
        headingRowHeight: 48,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 56,
        border: TableBorder.all(color: Colors.grey.shade300, width: 1),
        columns: const [
          DataColumn(
            label: Text(
              'No',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          DataColumn(
            label: Text(
              'Product Name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          DataColumn(
            label: Text(
              'P/N',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          DataColumn(
            label: Text(
              'HSN',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          DataColumn(
            label: Text(
              'UQC',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          DataColumn(
            label: Text(
              'Qty',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Rate Per Unit',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Amount',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'CGST%',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'SGST%',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'IGST%',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'UTGST%',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Tax Amt',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Total Amount',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            numeric: true,
          ),
        ],
        rows: items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;

          return DataRow(
            cells: [
              DataCell(Text('$index', style: const TextStyle(fontSize: 12))),
              DataCell(
                SizedBox(
                  width: 150,
                  child: Text(
                    item['product_name'] as String,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                Text(
                  item['part_number'] as String? ?? '-',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  item['hsn_code'] as String? ?? '-',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  item['uqc_code'] as String? ?? '-',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '${item['quantity']}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '₹${(item['selling_price'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '₹${(item['subtotal'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '${(item['cgst_rate'] as num).toStringAsFixed(2)}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '${(item['sgst_rate'] as num).toStringAsFixed(2)}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '${(item['igst_rate'] as num).toStringAsFixed(2)}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '${(item['utgst_rate'] as num).toStringAsFixed(2)}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '₹${(item['tax_amount'] as num).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ),
              DataCell(
                Text(
                  '₹${(item['total_amount'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEstimateTable(List<Map<String, dynamic>> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        horizontalMargin: 8,
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
        headingRowHeight: 48,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 56,
        border: TableBorder.all(color: Colors.grey.shade300, width: 1),
        columns: const [
          DataColumn(
            label: Text(
              'No',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          DataColumn(
            label: Text(
              'Product Name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          DataColumn(
            label: Text(
              'P/N',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          DataColumn(
            label: Text(
              'Qty',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Rate Per Unit',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Total Amount',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            numeric: true,
          ),
        ],
        rows: items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;

          return DataRow(
            cells: [
              DataCell(Text('$index', style: const TextStyle(fontSize: 12))),
              DataCell(
                SizedBox(
                  width: 200,
                  child: Text(
                    item['product_name'] as String,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                Text(
                  item['part_number'] as String? ?? '-',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '${item['quantity']}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '₹${(item['selling_price'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '₹${(item['total_amount'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
