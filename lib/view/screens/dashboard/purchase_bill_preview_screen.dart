import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../view_model/purchase_bill_automation_viewmodel.dart';
import '../../../model/apis/parsed_invoice.dart';

class PurchaseBillPreviewScreen extends ConsumerWidget {
  final String jsonResponse;

  const PurchaseBillPreviewScreen({super.key, required this.jsonResponse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseBillAutomationViewModelProvider);

    // Parse on first build
    if (state.parsedInvoice == null && !state.isLoading) {
      Future.microtask(() {
        ref
            .read(purchaseBillAutomationViewModelProvider.notifier)
            .parseInvoiceResponse(jsonResponse);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Purchase Bill'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main content
          state.isLoading && state.parsedInvoice == null
              ? const Center(child: CircularProgressIndicator())
              : state.error != null && state.parsedInvoice == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          state.error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : state.parsedInvoice == null
              ? const Center(child: Text('No invoice data'))
              : _buildInvoicePreview(context, ref, state),

          // Full-screen loading overlay when creating bill
          if (state.isCreating)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(strokeWidth: 4),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Creating Purchase Bill...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait while we save the data',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInvoicePreview(
    BuildContext context,
    WidgetRef ref,
    PurchaseBillAutomationState state,
  ) {
    final invoice = state.parsedInvoice!;
    final viewModel = ref.read(
      purchaseBillAutomationViewModelProvider.notifier,
    );

    return Column(
      children: [
        // Success message
        if (state.successMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.green[100],
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.successMessage!,
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

        // Error message
        if (state.error != null && state.successMessage == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.red[100],
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Invoice Header
                _buildInvoiceHeader(invoice, state),
                const SizedBox(height: 8),

                // Vendor Info
                _buildVendorInfo(invoice, state, viewModel),
                const SizedBox(height: 8),

                // Items Table
                _buildItemsTable(invoice, state, viewModel),
                const SizedBox(height: 8),

                // Unmatched Items Section
                if (state.unmatchedItems.isNotEmpty) ...[
                  _buildUnmatchedItemsSection(state),
                  const SizedBox(height: 8),
                ],

                // Totals
                _buildTotals(invoice),
                const SizedBox(height: 70), // Space for bottom button
              ],
            ),
          ),
        ),

        // Bottom action bar
        if (state.successMessage == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: state.isCreating
                        ? null
                        : () => viewModel.createPurchaseBill(),
                    icon: state.isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: Text(
                      state.isCreating
                          ? 'Creating Purchase Bill...'
                          : 'Create Purchase Bill',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInvoiceHeader(
    ParsedInvoice invoice,
    PurchaseBillAutomationState state,
  ) {
    // Format invoice number in our format (e.g., PB-001)
    final formattedInvoiceNumber = 'PB-${invoice.invoiceNumber}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Invoice Details',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          const Text(
            'Invoice Number:',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(width: 4),
          Text(
            formattedInvoiceNumber,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          ),
          const SizedBox(width: 16),
          const Text(
            'Invoice Date:',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(width: 4),
          Text(
            invoice.invoiceDate,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorInfo(
    ParsedInvoice invoice,
    PurchaseBillAutomationState state,
    PurchaseBillAutomationViewModel viewModel,
  ) {
    final vendorExists = state.existingVendor != null;
    final vendorSelected = state.selectedVendorId != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor Information (Left Side)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Vendor Information',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: vendorExists
                            ? Colors.green[100]
                            : Colors.orange[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        vendorExists ? 'Found' : 'Not Found',
                        style: TextStyle(
                          color: vendorExists
                              ? Colors.green[700]
                              : Colors.orange[700],
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Name', invoice.vendor.name),
                _buildInfoRow('GSTIN', invoice.vendor.gstin),
                _buildInfoRow('City', invoice.vendor.city),
                _buildInfoRow('State', invoice.vendor.state),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Vendor Selection & Stock Type (Right Side)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vendor selection dropdown if not found
                if (!vendorExists && state.availableVendors.isNotEmpty) ...[
                  const Text(
                    'Select Vendor:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: state.selectedVendorId,
                        hint: const Text(
                          'Choose...',
                          style: TextStyle(fontSize: 11),
                        ),
                        menuMaxHeight: 250,
                        items: state.availableVendors.map((vendor) {
                          return DropdownMenuItem<int>(
                            value: vendor.id,
                            child: Text(
                              vendor.gstNumber != null &&
                                      vendor.gstNumber!.isNotEmpty
                                  ? '${vendor.name} (${vendor.gstNumber})'
                                  : vendor.name,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (vendorId) {
                          if (vendorId != null) {
                            viewModel.setVendor(vendorId);
                          }
                        },
                      ),
                    ),
                  ),
                  if (!vendorSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Please select a vendor to continue.',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],

                // Stock Type Toggle
                const Text(
                  'Stock Type:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Non-Taxable (Orange)
                    InkWell(
                      onTap: () {
                        if (state.isBillTaxable) {
                          viewModel.toggleBillTaxable();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: !state.isBillTaxable
                              ? Colors.orange
                              : Colors.grey[200],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            bottomLeft: Radius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Non-Taxable',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: !state.isBillTaxable
                                ? Colors.white
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    // Taxable (Green)
                    InkWell(
                      onTap: () {
                        if (!state.isBillTaxable) {
                          viewModel.toggleBillTaxable();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: state.isBillTaxable
                              ? Colors.green
                              : Colors.grey[200],
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Taxable',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: state.isBillTaxable
                                ? Colors.white
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(
    ParsedInvoice invoice,
    PurchaseBillAutomationState state,
    PurchaseBillAutomationViewModel viewModel,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Matched Items (${invoice.items.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Select All button
                ElevatedButton.icon(
                  onPressed: () => viewModel.selectAllValidProducts(),
                  icon: const Icon(Icons.check_box, size: 14),
                  label: const Text(
                    'Select All',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 0),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Products found in database',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      Colors.grey[100],
                    ),
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 60,
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                    dataTextStyle: const TextStyle(fontSize: 11),
                    columns: const [
                      DataColumn(label: Text('Approve')),
                      DataColumn(label: Text('Part Number')),
                      DataColumn(label: Text('Description')),
                      DataColumn(label: Text('HSN')),
                      DataColumn(label: Text('Qty'), numeric: true),
                      DataColumn(label: Text('Rate'), numeric: true),
                      DataColumn(label: Text('Total'), numeric: true),
                    ],
                    rows: List.generate(invoice.items.length, (index) {
                      final item = invoice.items[index];
                      return DataRow(
                        color: MaterialStateProperty.all(
                          item.isApproved ? Colors.green[50] : null,
                        ),
                        cells: [
                          DataCell(
                            Checkbox(
                              value: item.isApproved,
                              onChanged: (value) =>
                                  viewModel.toggleItemApproval(index),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          DataCell(
                            Text(
                              item.partNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Text(
                                item.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.hsnCode,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.quantity.toString(),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            Text(
                              '₹${item.rate.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            Text(
                              '₹${item.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUnmatchedItemsSection(PurchaseBillAutomationState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[200]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Excluded Items (${state.unmatchedItems.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Products NOT found in database',
                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'These items were not included in the bill because they are not in your product database. Add them to your database and re-parse the invoice to include them.',
                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(
                            Colors.orange[100],
                          ),
                          dataRowMinHeight: 36,
                          dataRowMaxHeight: 60,
                          columnSpacing: 12,
                          horizontalMargin: 0,
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                          dataTextStyle: const TextStyle(fontSize: 11),
                          columns: const [
                            DataColumn(label: Text('Part Number')),
                            DataColumn(label: Text('Description')),
                            DataColumn(label: Text('HSN')),
                            DataColumn(label: Text('Qty'), numeric: true),
                            DataColumn(label: Text('Rate'), numeric: true),
                            DataColumn(label: Text('Total'), numeric: true),
                          ],
                          rows: state.unmatchedItems.map((item) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    item.partNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 180,
                                    child: Text(
                                      item.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item.hsnCode,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item.quantity.toString(),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '₹${item.rate.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '₹${item.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals(ParsedInvoice invoice) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTotalRow('Grand Total', invoice.totalAmount, isBold: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.black : Colors.grey[700],
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
