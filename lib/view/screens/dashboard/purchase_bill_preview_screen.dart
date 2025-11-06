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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Invoice Header
                _buildInvoiceHeader(invoice, state),
                const SizedBox(height: 16),

                // Vendor Info
                _buildVendorInfo(invoice, state, viewModel),
                const SizedBox(height: 16),

                // Bill-level taxable toggle
                _buildBillTaxableToggle(state, viewModel),
                const SizedBox(height: 16),

                // Items Table
                _buildItemsTable(invoice, state, viewModel),
                const SizedBox(height: 16),

                // Totals
                _buildTotals(invoice),
                const SizedBox(height: 100), // Space for bottom button
              ],
            ),
          ),
        ),

        // Bottom action bar
        if (state.successMessage == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
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
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      state.isCreating
                          ? 'Creating Purchase Bill...'
                          : 'Create Purchase Bill',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoice Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invoice Number',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invoice Date',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invoice.invoiceDate,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Vendor Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: vendorExists ? Colors.green[100] : Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  vendorExists ? 'Found' : 'Not Found',
                  style: TextStyle(
                    color: vendorExists
                        ? Colors.green[700]
                        : Colors.orange[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Name', invoice.vendor.name),
          _buildInfoRow('GSTIN', invoice.vendor.gstin),
          _buildInfoRow('City', invoice.vendor.city),
          _buildInfoRow('State', invoice.vendor.state),

          // Vendor selection dropdown if not found
          if (!vendorExists && state.availableVendors.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Select Existing Vendor:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: state.selectedVendorId,
                  hint: const Text('Choose a vendor...'),
                  items: state.availableVendors.map((vendor) {
                    return DropdownMenuItem<int>(
                      value: vendor.id,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            vendor.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (vendor.gstNumber != null &&
                              vendor.gstNumber!.isNotEmpty)
                            Text(
                              'GSTIN: ${vendor.gstNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
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
          ],

          if (!vendorSelected)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Please select a vendor to continue.',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillTaxableToggle(
    PurchaseBillAutomationState state,
    PurchaseBillAutomationViewModel viewModel,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          const Text(
            'Stock Type (Entire Bill):',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          ChoiceChip(
            label: const Text('Taxable'),
            selected: state.isBillTaxable,
            onSelected: (selected) {
              if (selected != state.isBillTaxable) {
                viewModel.toggleBillTaxable();
              }
            },
            selectedColor: Colors.blue[100],
            backgroundColor: Colors.grey[100],
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Non-Taxable'),
            selected: !state.isBillTaxable,
            onSelected: (selected) {
              if (selected != !state.isBillTaxable) {
                viewModel.toggleBillTaxable();
              }
            },
            selectedColor: Colors.orange[100],
            backgroundColor: Colors.grey[100],
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
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Line Items (${invoice.items.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: invoice.items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = invoice.items[index];
              final productMatch = state.productMatches[index];
              return _buildItemRow(index, item, productMatch, viewModel);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    int index,
    ParsedInvoiceItem item,
    int? productId,
    PurchaseBillAutomationViewModel viewModel,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: item.isApproved ? Colors.green[50] : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Approval checkbox
              Checkbox(
                value: item.isApproved,
                onChanged: (value) => viewModel.toggleItemApproval(index),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.partNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Matched',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HSN:',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(item.hsnCode, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Qty:',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'UQC:',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(item.uqc, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Amount:',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      '₹${item.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotals(ParsedInvoice invoice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Totals',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTotalRow('Subtotal', invoice.subtotal),
          _buildTotalRow('CGST', invoice.cgstAmount),
          _buildTotalRow('SGST', invoice.sgstAmount),
          const Divider(),
          _buildTotalRow('Grand Total', invoice.totalAmount, isBold: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.black : Colors.grey[700],
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
