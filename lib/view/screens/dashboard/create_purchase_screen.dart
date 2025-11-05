import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/database_provider.dart';
import '../../../model/purchase.dart';
import '../../../model/vendor.dart';
import '../../../repository/purchase_repository.dart';
import '../../../repository/vendor_repository.dart';
import '../../../repository/gst_rate_repository.dart';
import '../../../view_model/gst_rate_viewmodel.dart';
import '../../../view_model/pos_viewmodel.dart';
import '../../../view_model/vendor_viewmodel.dart';
import '../../widgets/vendor_form_dialog.dart';
import '../debit_notes_screen.dart';

// Providers
final purchaseRepositoryProvider = FutureProvider<PurchaseRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return PurchaseRepository(db);
});

final productListForPurchaseProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final db = await ref.watch(databaseProvider);
      return await db.rawQuery('''
    SELECT p.id, p.name, p.part_number, p.cost_price, p.is_taxable,
           h.code as hsn_code, u.code as uqc_code
    FROM products p
    LEFT JOIN hsn_codes h ON p.hsn_code_id = h.id
    LEFT JOIN uqcs u ON p.uqc_id = u.id
    WHERE p.is_deleted = 0 AND p.is_enabled = 1
    ORDER BY p.name
  ''');
    });

// IMPORTANT: This provider automatically refreshes when GST rates are updated
// in Masters > HSN Codes screen by watching gstRateViewModelProvider state
final gstRatesForPurchaseProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  // Watch the gstRateViewModelProvider to trigger refresh on updates
  ref.watch(gstRateViewModelProvider);

  final db = await ref.watch(databaseProvider);
  final repository = GstRateRepository(db);
  return repository.getAllGstRates();
});

final companyInfoProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final db = await ref.watch(databaseProvider);
  final result = await db.rawQuery('''
    SELECT gst_number FROM company_info
    WHERE is_primary = 1 AND is_deleted = 0 AND is_enabled = 1
    LIMIT 1
  ''');
  return result.isNotEmpty ? result.first : null;
});

class CreatePurchaseScreen extends ConsumerStatefulWidget {
  const CreatePurchaseScreen({super.key});

  @override
  ConsumerState<CreatePurchaseScreen> createState() =>
      _CreatePurchaseScreenState();
}

class _CreatePurchaseScreenState extends ConsumerState<CreatePurchaseScreen> {
  final _formKey = GlobalKey<FormState>();

  Vendor? _selectedVendor;
  String? _purchaseReferenceNumber;
  DateTime? _purchaseReferenceDate;

  final List<PurchaseRow> _rows = [];

  double _subtotal = 0.0;
  double _totalTax = 0.0;
  double _grandTotal = 0.0;

  bool _isSaving = false;
  bool _isTaxableBill = true; // Default: taxable bill

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _gstRates = [];
  String? _companyGstNumber;
  bool _isInterState = false;
  bool _dataInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    for (var row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addNewRow() {
    setState(() {
      _rows.add(
        PurchaseRow(
          products: _products,
          gstRates: _gstRates,
          isInterState: _isInterState,
          onChanged: _calculateTotals,
          onDelete: _deleteRow,
          onProductSelected: _checkAndMergeDuplicateProduct,
        ),
      );
    });
  }

  void _deleteRow(PurchaseRow row) {
    if (_rows.length > 1) {
      setState(() {
        _rows.remove(row);
        row.dispose();
        _calculateTotals();
      });
    }
  }

  void _checkAndMergeDuplicateProduct(PurchaseRow currentRow) {
    // Defer the check to the next frame to avoid conflicts with autocomplete lifecycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Only check if current row still exists and has a product selected
      if (!_rows.contains(currentRow) || currentRow.selectedProduct == null) {
        return;
      }

      // Don't merge if current row is not fully valid
      if (!currentRow.isValid()) {
        return;
      }

      final currentProductId = currentRow.selectedProduct!['id'] as int;
      final currentRate =
          double.tryParse(currentRow.rateController.text) ?? 0.0;

      // Extra safety check - rate must be positive
      if (currentRate <= 0) return;

      // Find other rows with same product (must exist BEFORE current row was selected)
      PurchaseRow? rowToMergeWith;

      for (int i = 0; i < _rows.length; i++) {
        final row = _rows[i];

        // Skip the current row itself
        if (row == currentRow) continue;

        // Skip if this row doesn't have a valid product selected
        if (row.selectedProduct == null) continue;

        // Check if row has same product ID
        if (row.selectedProduct!['id'] == currentProductId) {
          final existingRate = double.tryParse(row.rateController.text) ?? 0.0;

          // Only merge if the existing row is also valid
          if (!row.isValid()) continue;

          // Check if rates and GST values are the same (merge only if identical)
          if (existingRate == currentRate &&
              row.cgstController.text == currentRow.cgstController.text &&
              row.sgstController.text == currentRow.sgstController.text &&
              row.igstController.text == currentRow.igstController.text &&
              row.utgstController.text == currentRow.utgstController.text) {
            rowToMergeWith = row;
            break; // Found a match, stop searching
          }
        }
      }

      // If we found a row to merge with, do the merge
      if (rowToMergeWith != null) {
        final existingQty =
            int.tryParse(rowToMergeWith.quantityController.text) ?? 0;
        final currentQty =
            int.tryParse(currentRow.quantityController.text) ?? 0;
        final mergedQty = existingQty + currentQty;
        final productName = currentRow.selectedProduct!['name'] as String;

        // Update existing row with merged quantity
        rowToMergeWith.quantityController.text = mergedQty.toString();

        // Remove current row (the one that was just changed to duplicate)
        setState(() {
          _rows.remove(currentRow);
          currentRow.dispose();
          _calculateTotals();
        });

        // Show feedback to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Product "$productName" merged with existing entry. Quantity updated to $mergedQty.',
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _checkInterStateAndUpdateRows(Vendor? vendor) {
    if (vendor == null ||
        _companyGstNumber == null ||
        _companyGstNumber!.length < 2) {
      _isInterState = false;
      return;
    }

    final vendorGstNumber = vendor.gstNumber;

    // Edge cases: vendor has no GST number, assume inter-state for safety
    if (vendorGstNumber == null ||
        vendorGstNumber.isEmpty ||
        vendorGstNumber.length < 2) {
      _isInterState = true;
    } else {
      // Compare first 2 digits of GST numbers
      final companyStateCode = _companyGstNumber!.substring(0, 2);
      final vendorStateCode = vendorGstNumber.substring(0, 2);
      _isInterState = companyStateCode != vendorStateCode;
    }

    // Update all existing rows with new inter-state status
    for (var row in _rows) {
      row.updateInterState(_isInterState);
    }

    _calculateTotals();
  }

  void _calculateTotals() {
    double subtotal = 0.0;
    double totalTax = 0.0;

    for (var row in _rows) {
      if (row.isValid()) {
        subtotal += row.getSubtotal();
        totalTax += row.getTaxAmount();
      }
    }

    setState(() {
      _subtotal = subtotal;
      _totalTax = totalTax;
      _grandTotal = subtotal + totalTax;
    });
  }

  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedVendor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vendor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final validRows = _rows.where((row) => row.isValid()).toList();

    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one valid item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = await ref.read(purchaseRepositoryProvider.future);
      final purchaseNumber = await repository.generatePurchaseNumber();

      final purchase = Purchase(
        purchaseNumber: purchaseNumber,
        purchaseReferenceNumber: _purchaseReferenceNumber,
        purchaseReferenceDate: _purchaseReferenceDate,
        vendorId: _selectedVendor!.id!,
        subtotal: _subtotal,
        taxAmount: _totalTax,
        totalAmount: _grandTotal,
        isTaxableBill: _isTaxableBill,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final items = validRows.map((row) => row.toPurchaseItem()).toList();
      await repository.createPurchase(purchase, items);

      if (mounted) {
        // Invalidate POS provider to refresh product stock
        ref.invalidate(posViewModelProvider);
        // Invalidate purchases provider to refresh in Debit Notes screen
        ref.invalidate(purchasesProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase $purchaseNumber created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorListForPurchaseProvider);
    final productsAsync = ref.watch(productListForPurchaseProvider);
    final gstRatesAsync = ref.watch(gstRatesForPurchaseProvider);
    final companyAsync = ref.watch(companyInfoProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Create Purchase'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton.icon(
                onPressed: _rows.any((r) => r.isValid()) ? _savePurchase : null,
                icon: const Icon(Icons.save),
                label: const Text('Save Purchase'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
      body: vendorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (vendors) => productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (products) => gstRatesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
            data: (gstRates) => companyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (company) {
                if (!_dataInitialized) {
                  _products = products;
                  _gstRates = gstRates;
                  _companyGstNumber = company?['gst_number'] as String?;
                  _dataInitialized = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_rows.isEmpty) {
                      _addNewRow();
                    }
                  });
                } else {
                  _products = products;
                  _gstRates = gstRates;
                  _companyGstNumber = company?['gst_number'] as String?;
                  for (var row in _rows) {
                    row.updateData(_products, _gstRates);
                  }
                }
                return _buildForm(vendors);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(List<Vendor> vendors) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildHeader(vendors),
          _buildTableHeader(),
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (context, index) => KeyedSubtree(
                  key: _rows[index].key,
                  child: _rows[index].buildRow(index + 1),
                ),
              ),
            ),
          ),
          // (Totals moved to footer)
          _buildFooter(),
        ],
      ),
    );
  }

  /// Fuzzy search helper
  bool _fuzzyMatch(String searchText, String targetText) {
    if (searchText.isEmpty) return true;
    if (targetText.isEmpty) return false;

    final search = searchText.toLowerCase();
    final target = targetText.toLowerCase();

    int searchIndex = 0;
    int targetIndex = 0;

    while (searchIndex < search.length && targetIndex < target.length) {
      if (search[searchIndex] == target[targetIndex]) {
        searchIndex++;
      }
      targetIndex++;
    }

    return searchIndex == search.length;
  }

  /// Search vendor across multiple fields
  bool _matchesVendor(Vendor vendor, String query) {
    if (query.isEmpty) return true;

    if (_fuzzyMatch(query, vendor.name)) return true;
    if (vendor.legalName != null && _fuzzyMatch(query, vendor.legalName!)) {
      return true;
    }
    if (vendor.gstNumber != null && _fuzzyMatch(query, vendor.gstNumber!)) {
      return true;
    }
    if (vendor.phone != null && _fuzzyMatch(query, vendor.phone!)) {
      return true;
    }
    if (vendor.email != null && _fuzzyMatch(query, vendor.email!)) {
      return true;
    }

    return false;
  }

  void _showAddVendorDialog() async {
    final db = await ref.read(databaseProvider);
    final vendorRepository = VendorRepository(db);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => VendorFormDialog(
        vendor: null,
        onSave: (newVendor) async {
          Navigator.of(context).pop();
          try {
            final vendorId = await vendorRepository.createVendor(newVendor);
            // Refresh vendor lists for both Create Purchase and Masters screens
            ref.invalidate(vendorListForPurchaseProvider);
            ref.invalidate(vendorProvider);
            // Wait for refresh
            await Future.delayed(const Duration(milliseconds: 100));
            // Auto-select the new vendor
            final vendors = await ref.read(
              vendorListForPurchaseProvider.future,
            );
            final vendor = vendors.firstWhere((v) => v.id == vendorId);
            setState(() {
              _selectedVendor = vendor;
              _checkInterStateAndUpdateRows(vendor);
            });
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to create vendor: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildHeader(List<Vendor> vendors) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: Autocomplete<Vendor>(
                    key: ValueKey(_selectedVendor?.id),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return vendors;
                      }
                      return vendors.where((vendor) {
                        return _matchesVendor(vendor, textEditingValue.text);
                      });
                    },
                    displayStringForOption: (Vendor vendor) => vendor.name,
                    onSelected: (Vendor vendor) {
                      setState(() {
                        _selectedVendor = vendor;
                        _checkInterStateAndUpdateRows(vendor);
                      });
                    },
                    initialValue: _selectedVendor != null
                        ? TextEditingValue(text: _selectedVendor!.name)
                        : null,
                    fieldViewBuilder:
                        (
                          BuildContext context,
                          TextEditingController textController,
                          FocusNode focusNode,
                          VoidCallback onFieldSubmitted,
                        ) {
                          return TextField(
                            controller: textController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Vendor *',
                              hintText: 'Type to search vendors...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              errorText:
                                  _selectedVendor == null &&
                                      textController.text.isNotEmpty
                                  ? 'Please select a vendor from the list'
                                  : null,
                            ),
                            onSubmitted: (value) => onFieldSubmitted(),
                          );
                        },
                    optionsViewBuilder:
                        (
                          BuildContext context,
                          AutocompleteOnSelected<Vendor> onSelected,
                          Iterable<Vendor> options,
                        ) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 300,
                                  maxWidth: 400,
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                        final Vendor vendor = options.elementAt(
                                          index,
                                        );
                                        return InkWell(
                                          onTap: () => onSelected(vendor),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.shade200,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  vendor.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                if (vendor.gstNumber !=
                                                    null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'GST: ${vendor.gstNumber}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                                if (vendor.phone != null) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    vendor.phone!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                ),
                              ),
                            ),
                          );
                        },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                  onPressed: _showAddVendorDialog,
                  tooltip: 'Add New Vendor',
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              decoration: InputDecoration(
                labelText: 'Reference Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) =>
                  _purchaseReferenceNumber = value.isEmpty ? null : value,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _purchaseReferenceDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _purchaseReferenceDate = date;
                  });
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Reference Date',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                child: Text(
                  _purchaseReferenceDate != null
                      ? '${_purchaseReferenceDate!.day.toString().padLeft(2, '0')}/${_purchaseReferenceDate!.month.toString().padLeft(2, '0')}/${_purchaseReferenceDate!.year}'
                      : 'Select date',
                  style: TextStyle(
                    color: _purchaseReferenceDate != null
                        ? Colors.black87
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Taxable Bill Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Taxable Bill',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _isTaxableBill,
                  onChanged: (value) {
                    setState(() {
                      _isTaxableBill = value;
                    });
                  },
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildHeaderCell('No', width: 40),
          _buildHeaderCell('Product Name', flex: 3),
          _buildHeaderCell('P/N', flex: 1),
          _buildHeaderCell('HSN', flex: 1),
          _buildHeaderCell('UQC', flex: 1),
          _buildHeaderCell('Qty', flex: 1),
          _buildHeaderCell('Rate Per Unit', flex: 1),
          _buildHeaderCell('Amount', flex: 1),
          _buildHeaderCell('CGST%', width: 60),
          _buildHeaderCell('SGST%', width: 60),
          _buildHeaderCell('IGST/UTGST%', width: 60),
          _buildHeaderCell('CESS%', width: 60),
          _buildHeaderCell('Tax Amt', flex: 1),
          _buildHeaderCell('Total Amount', flex: 1),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, {int flex = 1, double? width}) {
    final child = Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );

    if (width != null) {
      return SizedBox(width: width, child: child);
    }
    return Expanded(flex: flex, child: child);
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _addNewRow,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add Row'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
            ),
          ),
          const Spacer(),
          _buildTotalRow('Subtotal:', _subtotal),
          const SizedBox(width: 40),
          _buildTotalRow('Tax:', _totalTax),
          const SizedBox(width: 40),
          _buildTotalRow('Total:', _grandTotal, isGrand: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isGrand = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isGrand ? FontWeight.w700 : FontWeight.w600,
            fontSize: isGrand ? 16 : 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: isGrand ? 18 : 14,
            color: isGrand ? Colors.green.shade700 : Colors.black87,
          ),
        ),
      ],
    );
  }
}

// Excel-like Purchase Row
class PurchaseRow {
  final UniqueKey key = UniqueKey();
  List<Map<String, dynamic>> products;
  List<Map<String, dynamic>> gstRates;
  bool isInterState;
  final VoidCallback onChanged;
  final Function(PurchaseRow) onDelete;
  final Function(PurchaseRow)? onProductSelected;

  final TextEditingController productNameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController rateController = TextEditingController();
  final TextEditingController cgstController = TextEditingController(text: '0');
  final TextEditingController sgstController = TextEditingController(text: '0');
  final TextEditingController igstController = TextEditingController(text: '0');
  final TextEditingController utgstController = TextEditingController(
    text: '0',
  );

  Map<String, dynamic>? selectedProduct;
  String? hsnCode;
  String? uqcCode;

  PurchaseRow({
    required this.products,
    required this.gstRates,
    required this.isInterState,
    required this.onChanged,
    required this.onDelete,
    this.onProductSelected,
  }) {
    quantityController.addListener(onChanged);
    rateController.addListener(onChanged);
    cgstController.addListener(onChanged);
    sgstController.addListener(onChanged);
    igstController.addListener(onChanged);
    utgstController.addListener(onChanged);
  }

  void updateData(
    List<Map<String, dynamic>> newProducts,
    List<Map<String, dynamic>> newGstRates,
  ) {
    products = newProducts;
    gstRates = newGstRates;
  }

  void updateInterState(bool newInterState) {
    if (isInterState != newInterState) {
      isInterState = newInterState;
      // Re-apply GST rates if product is selected
      if (selectedProduct != null && hsnCode != null) {
        final isTaxable = (selectedProduct!['is_taxable'] as int?) == 1;
        if (isTaxable) {
          _autoFillGstRates(hsnCode!);
        }
      }
    }
  }

  void dispose() {
    productNameController.dispose();
    quantityController.dispose();
    rateController.dispose();
    cgstController.dispose();
    sgstController.dispose();
    igstController.dispose();
    utgstController.dispose();
  }

  bool isValid() {
    return selectedProduct != null &&
        rateController.text.isNotEmpty &&
        double.tryParse(rateController.text) != null &&
        double.parse(rateController.text) > 0 &&
        quantityController.text.isNotEmpty &&
        int.tryParse(quantityController.text) != null &&
        int.parse(quantityController.text) > 0;
  }

  double getSubtotal() {
    if (!isValid()) return 0.0;
    final rate = double.parse(rateController.text);
    final qty = int.parse(quantityController.text);
    return rate * qty;
  }

  double getTaxAmount() {
    final subtotal = getSubtotal();
    final cgst = double.tryParse(cgstController.text) ?? 0.0;
    final sgst = double.tryParse(sgstController.text) ?? 0.0;
    final igst = double.tryParse(igstController.text) ?? 0.0;
    final utgst = double.tryParse(utgstController.text) ?? 0.0;
    return (subtotal * (cgst + sgst + igst + utgst)) / 100;
  }

  double getTotalAmount() {
    return getSubtotal() + getTaxAmount();
  }

  PurchaseItem toPurchaseItem() {
    final subtotal = getSubtotal();
    final cgst = double.tryParse(cgstController.text) ?? 0.0;
    final sgst = double.tryParse(sgstController.text) ?? 0.0;
    final igst = double.tryParse(igstController.text) ?? 0.0;
    final utgst = double.tryParse(utgstController.text) ?? 0.0;

    return PurchaseItem(
      productId: selectedProduct!['id'] as int,
      productName: selectedProduct!['name'] as String,
      partNumber: selectedProduct!['part_number'] as String?,
      hsnCode: hsnCode,
      uqcCode: uqcCode,
      costPrice: double.parse(rateController.text),
      quantity: int.parse(quantityController.text),
      subtotal: subtotal,
      cgstRate: cgst,
      sgstRate: sgst,
      igstRate: igst,
      utgstRate: utgst,
      cgstAmount: (subtotal * cgst) / 100,
      sgstAmount: (subtotal * sgst) / 100,
      igstAmount: (subtotal * igst) / 100,
      utgstAmount: (subtotal * utgst) / 100,
      taxAmount: getTaxAmount(),
      totalAmount: getTotalAmount(),
    );
  }

  void _autoFillGstRates(String hsn) {
    final matchingRate = gstRates.firstWhere(
      (rate) => rate['hsn_code'] == hsn && rate['is_enabled'] == 1,
      orElse: () => <String, dynamic>{},
    );

    if (matchingRate.isNotEmpty) {
      if (isInterState) {
        // Inter-state: Apply IGST only, others are 0
        cgstController.text = '0.00';
        sgstController.text = '0.00';
        igstController.text = (matchingRate['igst'] as num).toStringAsFixed(2);
        utgstController.text = '0.00';
      } else {
        // Intra-state: Apply CGST, SGST, UTGST, IGST is 0
        cgstController.text = (matchingRate['cgst'] as num).toStringAsFixed(2);
        sgstController.text = (matchingRate['sgst'] as num).toStringAsFixed(2);
        igstController.text = '0.00';
        utgstController.text = (matchingRate['utgst'] as num).toStringAsFixed(
          2,
        );
      }
    }
  }

  Widget buildRow(int serialNumber) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Serial Number
          SizedBox(
            width: 40,
            child: Text(
              '$serialNumber',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Product Name (Autocomplete)
          Expanded(flex: 3, child: _buildProductAutocomplete()),
          // Part Number (Auto-filled, Read-only)
          Expanded(
            child: _buildDisplayText(
              selectedProduct?['part_number'] as String? ?? '-',
            ),
          ),
          // HSN (Auto-filled)
          Expanded(child: _buildDisplayText(hsnCode ?? '-')),
          // UQC (Auto-filled)
          Expanded(child: _buildDisplayText(uqcCode ?? '-')),
          // Quantity (Editable)
          Expanded(
            child: _buildEditableCell(
              controller: quantityController,
              isNumber: true,
              digitsOnly: true,
              textAlign: TextAlign.center,
            ),
          ),
          // Rate (Auto-filled, Editable)
          Expanded(
            child: _buildEditableCell(
              controller: rateController,
              isNumber: true,
              textAlign: TextAlign.right,
            ),
          ),
          // Amount (Calculated)
          Expanded(
            child: _buildDisplayText(
              '₹${getSubtotal().toStringAsFixed(2)}',
              align: TextAlign.right,
            ),
          ),
          // CGST (Auto-filled, Read-only)
          SizedBox(
            width: 60,
            child: _buildDisplayText(
              cgstController.text,
              align: TextAlign.center,
            ),
          ),
          // SGST (Auto-filled, Read-only)
          SizedBox(
            width: 60,
            child: _buildDisplayText(
              sgstController.text,
              align: TextAlign.center,
            ),
          ),
          // IGST (Auto-filled, Read-only)
          SizedBox(
            width: 60,
            child: _buildDisplayText(
              igstController.text,
              align: TextAlign.center,
            ),
          ),
          // UTGST (Auto-filled, Read-only)
          SizedBox(
            width: 60,
            child: _buildDisplayText(
              utgstController.text,
              align: TextAlign.center,
            ),
          ),
          // Tax Amount (Calculated)
          Expanded(
            child: _buildDisplayText(
              '₹${getTaxAmount().toStringAsFixed(2)}',
              align: TextAlign.right,
              color: Colors.orange.shade700,
            ),
          ),
          // Total (Calculated)
          Expanded(
            child: _buildDisplayText(
              '₹${getTotalAmount().toStringAsFixed(2)}',
              align: TextAlign.right,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Delete Button
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
              onPressed: () => onDelete(this),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Delete row',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
        final text = textEditingValue.text.toLowerCase();
        return products.where((p) {
          final name = (p['name'] as String).toLowerCase();
          final partNo = (p['part_number'] as String?)?.toLowerCase() ?? '';
          return name.contains(text) || partNo.contains(text);
        });
      },
      displayStringForOption: (option) {
        final name = option['name'] as String;
        final partNumber = option['part_number'] as String?;
        return partNumber != null && partNumber.isNotEmpty
            ? '$name ($partNumber)'
            : name;
      },
      onSelected: (option) {
        selectedProduct = option;
        hsnCode = option['hsn_code'] as String?;
        uqcCode = option['uqc_code'] as String?;
        rateController.text = (option['cost_price'] as num).toString();

        // Update the product name controller to show the selected product
        productNameController.text = option['name'] as String;

        final isTaxable = (option['is_taxable'] as int?) == 1;
        if (isTaxable && hsnCode != null) {
          _autoFillGstRates(hsnCode!);
        } else {
          cgstController.text = '0';
          sgstController.text = '0';
          igstController.text = '0';
          utgstController.text = '0';
        }
        onChanged();

        // Check for duplicates and merge if needed
        onProductSelected?.call(this);
      },
      optionsViewBuilder: (context, onSelected, options) {
        final optionsList = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: optionsList.length,
                // Optimize scrollbar performance for large lists
                itemExtent: 48, // Fixed height for each option
                cacheExtent:
                    500, // Cache more items for smooth scrollbar dragging
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                itemBuilder: (context, index) {
                  final option = optionsList[index];
                  final name = option['name'] as String;
                  final partNumber = option['part_number'] as String?;
                  final displayText =
                      partNumber != null && partNumber.isNotEmpty
                      ? '$name ($partNumber)'
                      : name;

                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        displayText,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        // Sync our controller with the autocomplete's controller
        if (productNameController.text.isNotEmpty && controller.text.isEmpty) {
          controller.text = productNameController.text;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (value) {
              // Keep our controller in sync
              productNameController.text = value;
            },
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search by name or part number...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            onSubmitted: (_) => onSubmitted(),
          ),
        );
      },
    );
  }

  Widget _buildEditableCell({
    required TextEditingController controller,
    bool isNumber = false,
    bool digitsOnly = false,
    TextAlign textAlign = TextAlign.left,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: digitsOnly
            ? [FilteringTextInputFormatter.digitsOnly]
            : isNumber
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
            : null,
        textAlign: textAlign,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }

  Widget _buildDisplayText(
    String text, {
    TextAlign align = TextAlign.center,
    Color? color,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: color ?? Colors.black87,
          fontWeight: fontWeight,
        ),
        textAlign: align,
      ),
    );
  }
}
