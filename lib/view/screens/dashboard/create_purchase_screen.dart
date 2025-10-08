import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/database_provider.dart';
import '../../../model/purchase.dart';
import '../../../repository/purchase_repository.dart';
import '../../../repository/vendor_repository.dart';
import '../../../repository/gst_rate_repository.dart';

// Providers
final purchaseRepositoryProvider = FutureProvider<PurchaseRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return PurchaseRepository(db);
});

final vendorListForPurchaseProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final db = await ref.watch(databaseProvider);
      final repository = VendorRepository(db);
      final vendors = await repository.getAllVendors();
      return vendors.map((v) => v.toJson()).toList();
    });

final productListForPurchaseProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final db = await ref.watch(databaseProvider);
      return await db.rawQuery('''
    SELECT p.id, p.name, p.part_number, p.cost_price, p.is_taxable,
           h.code as hsn_code, u.code as uqc_code, u.description as uqc_description
    FROM products p
    LEFT JOIN hsn_codes h ON p.hsn_code_id = h.id
    LEFT JOIN uqcs u ON p.uqc_id = u.id
    WHERE p.is_deleted = 0 AND p.is_enabled = 1
    ORDER BY p.name
  ''');
    });

final gstRatesForPurchaseProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  final repository = GstRateRepository(db);
  return repository.getAllGstRates();
});

class CreatePurchaseScreen extends ConsumerStatefulWidget {
  const CreatePurchaseScreen({super.key});

  @override
  ConsumerState<CreatePurchaseScreen> createState() =>
      _CreatePurchaseScreenState();
}

class _CreatePurchaseScreenState extends ConsumerState<CreatePurchaseScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  int? _selectedVendorId;
  String? _purchaseReferenceNumber;
  DateTime? _purchaseReferenceDate;

  // Inline editable rows
  final List<_InlineItemRow> _itemRows = [];

  // For calculations
  double _subtotal = 0.0;
  double _totalTax = 0.0;
  double _grandTotal = 0.0;

  bool _isSaving = false;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _gstRates = [];
  bool _dataInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  void _addNewRow() {
    final row = _InlineItemRow(
      onChanged: _onRowChanged,
      onDelete: _onRowDelete,
      products: _products,
      gstRates: _gstRates,
    );
    setState(() {
      _itemRows.add(row);
    });
  }

  void _onRowChanged() {
    _calculateTotals();
  }

  void _onRowDelete(_InlineItemRow row) {
    if (_itemRows.length > 1) {
      setState(() {
        _itemRows.remove(row);
        _calculateTotals();
      });
    }
  }

  void _calculateTotals() {
    double subtotal = 0.0;
    double totalTax = 0.0;
    double grandTotal = 0.0;

    for (var row in _itemRows) {
      if (row.isValid()) {
        subtotal += row.getSubtotal();
        totalTax += row.getTaxAmount();
        grandTotal += row.getTotalAmount();
      }
    }

    setState(() {
      _subtotal = subtotal;
      _totalTax = totalTax;
      _grandTotal = grandTotal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorListForPurchaseProvider);
    final productsAsync = ref.watch(productListForPurchaseProvider);
    final gstRatesAsync = ref.watch(gstRatesForPurchaseProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Purchase'),
        backgroundColor: AppColors.success,
        foregroundColor: AppColors.white,
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
            TextButton.icon(
              onPressed: _hasValidItems() ? _savePurchase : null,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text(
                'Save Purchase',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          const SizedBox(width: 8),
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
            data: (gstRates) {
              // Update data and ensure rows are initialized
              if (!_dataInitialized) {
                _products = products;
                _gstRates = gstRates;
                _dataInitialized = true;
                // Add first row after data is loaded
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_itemRows.isEmpty) {
                    _addNewRow();
                  }
                });
              } else {
                // Update existing rows with new data
                final productsChanged = _products.length != products.length;
                final gstRatesChanged = _gstRates.length != gstRates.length;

                _products = products;
                _gstRates = gstRates;

                // Update products and gstRates in existing rows
                if (productsChanged || gstRatesChanged) {
                  for (var row in _itemRows) {
                    row.updateData(_products, _gstRates);
                  }
                }
              }
              return _buildPurchaseForm(vendors);
            },
          ),
        ),
      ),
    );
  }

  bool _hasValidItems() {
    return _itemRows.any((row) => row.isValid());
  }

  Widget _buildPurchaseForm(List<Map<String, dynamic>> vendors) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Header section
          _buildHeaderSection(vendors),
          const Divider(height: 1),
          // Table header
          _buildTableHeader(),
          // Items table
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (int i = 0; i < _itemRows.length; i++)
                    _itemRows[i].buildRow(i + 1),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Footer with add button and totals
          _buildFooterSection(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(List<Map<String, dynamic>> vendors) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      color: AppColors.white,
      child: Row(
        children: [
          // Vendor dropdown
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int>(
              value: _selectedVendorId,
              decoration: InputDecoration(
                labelText: 'Vendor *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingM,
                  vertical: AppSizes.paddingS,
                ),
              ),
              isExpanded: true,
              items: vendors.map((vendor) {
                return DropdownMenuItem<int>(
                  value: vendor['id'] as int,
                  child: Text(
                    '${vendor['name']} - ${vendor['gst_number'] ?? 'No GST'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedVendorId = value;
                });
              },
              validator: (value) =>
                  value == null ? 'Please select a vendor' : null,
            ),
          ),
          const SizedBox(width: AppSizes.paddingL),
          // Reference number
          Expanded(
            child: TextFormField(
              decoration: InputDecoration(
                labelText: 'Reference Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingM,
                  vertical: AppSizes.paddingS,
                ),
              ),
              onChanged: (value) =>
                  _purchaseReferenceNumber = value.isEmpty ? null : value,
            ),
          ),
          const SizedBox(width: AppSizes.paddingL),
          // Reference date
          Expanded(
            child: InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _purchaseReferenceDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
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
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingM,
                    vertical: AppSizes.paddingS,
                  ),
                ),
                child: Text(
                  _purchaseReferenceDate != null
                      ? '${_purchaseReferenceDate!.day.toString().padLeft(2, '0')}/${_purchaseReferenceDate!.month.toString().padLeft(2, '0')}/${_purchaseReferenceDate!.year}'
                      : 'Select date',
                  style: TextStyle(
                    color: _purchaseReferenceDate != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingL,
        vertical: AppSizes.paddingM,
      ),
      color: AppColors.primary.withOpacity(0.1),
      child: Row(
        children: [
          _buildHeaderCell('#', width: 40),
          _buildHeaderCell('Product', flex: 3),
          _buildHeaderCell('HSN', flex: 1),
          _buildHeaderCell('Cost Price', flex: 1),
          _buildHeaderCell('Qty', flex: 1),
          _buildHeaderCell('Subtotal', flex: 1),
          _buildHeaderCell('CGST%', flex: 1),
          _buildHeaderCell('SGST%', flex: 1),
          _buildHeaderCell('IGST%', flex: 1),
          _buildHeaderCell('UTGST%', flex: 1),
          _buildHeaderCell('Tax', flex: 1),
          _buildHeaderCell('Total', flex: 1),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, {int flex = 1, double? width}) {
    final child = Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: AppSizes.fontM,
        color: AppColors.primary,
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: child);
    }
    return Expanded(flex: flex, child: child);
  }

  Widget _buildFooterSection() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      color: AppColors.white,
      child: Column(
        children: [
          // Add row button
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _addNewRow,
              icon: const Icon(Icons.add),
              label: const Text('Add Row'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingL,
                  vertical: AppSizes.paddingM,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.paddingL),
          // Totals
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildTotalRow('Subtotal:', _subtotal),
              const SizedBox(width: AppSizes.paddingXL),
              _buildTotalRow('Total Tax:', _totalTax),
              const SizedBox(width: AppSizes.paddingXL),
              _buildTotalRow('Grand Total:', _grandTotal, isGrandTotal: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount, {
    bool isGrandTotal = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isGrandTotal ? AppSizes.fontL : AppSizes.fontM,
            fontWeight: isGrandTotal ? FontWeight.w700 : FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: AppSizes.paddingM),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isGrandTotal ? AppSizes.fontXL : AppSizes.fontL,
            fontWeight: FontWeight.w700,
            color: isGrandTotal ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final validItems = _itemRows.where((row) => row.isValid()).toList();

    if (validItems.isEmpty) {
      // Find what's wrong with the items
      String errorMessage = 'Please add at least one valid item';

      for (var row in _itemRows) {
        if (row.selectedProduct == null) {
          errorMessage = 'Please select a product from the dropdown';
          break;
        }

        final price = double.tryParse(row.costPriceController.text);
        if (price == null || price <= 0) {
          errorMessage = 'Cost price must be greater than 0';
          break;
        }

        final qty = int.tryParse(row.quantityController.text);
        if (qty == null || qty <= 0) {
          errorMessage = 'Quantity must be greater than 0';
          break;
        }

        final cgst = double.tryParse(row.cgstController.text) ?? 0.0;
        final sgst = double.tryParse(row.sgstController.text) ?? 0.0;
        final igst = double.tryParse(row.igstController.text) ?? 0.0;
        final utgst = double.tryParse(row.utgstController.text) ?? 0.0;

        if (cgst < 0 ||
            cgst > 100 ||
            sgst < 0 ||
            sgst > 100 ||
            igst < 0 ||
            igst > 100 ||
            utgst < 0 ||
            utgst > 100) {
          errorMessage = 'GST rates must be between 0 and 100';
          break;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
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
        vendorId: _selectedVendorId!,
        subtotal: _subtotal,
        taxAmount: _totalTax,
        totalAmount: _grandTotal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final items = validItems.map((row) => row.toPurchaseItem()).toList();
      await repository.createPurchase(purchase, items);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase $purchaseNumber created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
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
}

// Inline editable item row
class _InlineItemRow {
  final VoidCallback onChanged;
  final Function(_InlineItemRow) onDelete;
  List<Map<String, dynamic>> products;
  List<Map<String, dynamic>> gstRates;

  final TextEditingController productController = TextEditingController();
  final TextEditingController costPriceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController cgstController = TextEditingController(text: '0');
  final TextEditingController sgstController = TextEditingController(text: '0');
  final TextEditingController igstController = TextEditingController(text: '0');
  final TextEditingController utgstController = TextEditingController(
    text: '0',
  );

  Map<String, dynamic>? selectedProduct;
  String? hsnCode;
  String? uqcCode;

  _InlineItemRow({
    required this.onChanged,
    required this.onDelete,
    required this.products,
    required this.gstRates,
  }) {
    // Add listeners
    costPriceController.addListener(onChanged);
    quantityController.addListener(onChanged);
    cgstController.addListener(() {
      _validateAndClampGst(cgstController);
      onChanged();
    });
    sgstController.addListener(() {
      _validateAndClampGst(sgstController);
      onChanged();
    });
    igstController.addListener(() {
      _validateAndClampGst(igstController);
      onChanged();
    });
    utgstController.addListener(() {
      _validateAndClampGst(utgstController);
      onChanged();
    });
  }

  // Update the products and gstRates data for this row
  void updateData(
    List<Map<String, dynamic>> newProducts,
    List<Map<String, dynamic>> newGstRates,
  ) {
    products = newProducts;
    gstRates = newGstRates;
  }

  void _validateAndClampGst(TextEditingController controller) {
    final value = double.tryParse(controller.text);
    if (value != null) {
      if (value < 0) {
        controller.text = '0';
      } else if (value > 100) {
        controller.text = '100';
      }
    }
  }

  bool isValid() {
    if (selectedProduct == null) return false;

    final price = double.tryParse(costPriceController.text);
    if (price == null || price <= 0) return false;

    final qty = int.tryParse(quantityController.text);
    if (qty == null || qty <= 0) return false;

    // Validate GST rates are between 0-100
    final cgst = double.tryParse(cgstController.text) ?? 0.0;
    final sgst = double.tryParse(sgstController.text) ?? 0.0;
    final igst = double.tryParse(igstController.text) ?? 0.0;
    final utgst = double.tryParse(utgstController.text) ?? 0.0;

    if (cgst < 0 || cgst > 100) return false;
    if (sgst < 0 || sgst > 100) return false;
    if (igst < 0 || igst > 100) return false;
    if (utgst < 0 || utgst > 100) return false;

    return true;
  }

  double getSubtotal() {
    if (!isValid()) return 0.0;
    final price = double.tryParse(costPriceController.text) ?? 0.0;
    final qty = int.tryParse(quantityController.text) ?? 0;
    return price * qty;
  }

  double getTaxAmount() {
    if (!isValid()) return 0.0;
    final subtotal = getSubtotal();
    final cgst = double.tryParse(cgstController.text) ?? 0.0;
    final sgst = double.tryParse(sgstController.text) ?? 0.0;
    final igst = double.tryParse(igstController.text) ?? 0.0;
    final utgst = double.tryParse(utgstController.text) ?? 0.0;
    return (subtotal * cgst / 100) +
        (subtotal * sgst / 100) +
        (subtotal * igst / 100) +
        (subtotal * utgst / 100);
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

    final cgstAmount = subtotal * cgst / 100;
    final sgstAmount = subtotal * sgst / 100;
    final igstAmount = subtotal * igst / 100;
    final utgstAmount = subtotal * utgst / 100;

    return PurchaseItem(
      productId: selectedProduct!['id'] as int,
      productName: selectedProduct!['name'] as String,
      partNumber: selectedProduct!['part_number'] as String?,
      hsnCode: hsnCode,
      uqcCode: uqcCode,
      costPrice: double.parse(costPriceController.text),
      quantity: int.parse(quantityController.text),
      subtotal: subtotal,
      cgstRate: cgst,
      sgstRate: sgst,
      igstRate: igst,
      utgstRate: utgst,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      igstAmount: igstAmount,
      utgstAmount: utgstAmount,
      taxAmount: getTaxAmount(),
      totalAmount: getTotalAmount(),
    );
  }

  void _autoFillGstRates(String hsnCode) {
    final matchingRate = gstRates.firstWhere(
      (rate) => rate['hsn_code'] == hsnCode && rate['is_enabled'] == 1,
      orElse: () => <String, dynamic>{},
    );

    if (matchingRate.isNotEmpty) {
      cgstController.text =
          (matchingRate['cgst'] as num?)?.toStringAsFixed(2) ?? '0';
      sgstController.text =
          (matchingRate['sgst'] as num?)?.toStringAsFixed(2) ?? '0';
      igstController.text =
          (matchingRate['igst'] as num?)?.toStringAsFixed(2) ?? '0';
      utgstController.text =
          (matchingRate['utgst'] as num?)?.toStringAsFixed(2) ?? '0';
    }
  }

  Widget buildRow(int serialNumber) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingL,
        vertical: AppSizes.paddingS,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          // Serial number
          SizedBox(
            width: 40,
            child: Text(
              '$serialNumber',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // Product name (autocomplete)
          Expanded(
            flex: 3,
            child: Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                final text = textEditingValue.text.toLowerCase();
                final matches = products.where((p) {
                  final name = (p['name'] as String).toLowerCase();
                  final partNo =
                      (p['part_number'] as String?)?.toLowerCase() ?? '';
                  return name.contains(text) || partNo.contains(text);
                }).toList();
                return matches;
              },
              displayStringForOption: (option) =>
                  '${option['name']} ${option['part_number'] != null ? '(${option['part_number']})' : ''}',
              onSelected: (option) {
                selectedProduct = option;
                productController.text = option['name'] as String;
                hsnCode = option['hsn_code'] as String?;
                uqcCode = option['uqc_code'] as String?;
                // Auto-fill default values from database
                costPriceController.text = option['cost_price'].toString();

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
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                // Check if the current text matches a product
                final isValidProduct =
                    selectedProduct != null &&
                    productController.text == selectedProduct!['name'];

                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onSubmitted: (value) {
                    // Handle Enter key - select first match if available
                    onSubmitted();
                  },
                  decoration: InputDecoration(
                    hintText: 'Type product name...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    // Visual feedback for invalid selection
                    suffixIcon: controller.text.isNotEmpty && !isValidProduct
                        ? const Icon(Icons.warning_amber_rounded, size: 16)
                        : isValidProduct
                        ? const Icon(Icons.check_circle, size: 16)
                        : null,
                    suffixIconColor:
                        controller.text.isNotEmpty && !isValidProduct
                        ? AppColors.error
                        : AppColors.success,
                  ),
                  style: TextStyle(
                    fontSize: AppSizes.fontM,
                    color: controller.text.isNotEmpty && !isValidProduct
                        ? AppColors.error
                        : AppColors.textPrimary,
                  ),
                  onChanged: (value) {
                    // Clear selected product if text doesn't match
                    if (selectedProduct != null &&
                        value != selectedProduct!['name']) {
                      selectedProduct = null;
                      hsnCode = null;
                      uqcCode = null;
                      onChanged();
                    }
                  },
                );
              },
            ),
          ),
          // HSN
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(
                hsnCode ?? '-',
                style: TextStyle(
                  fontSize: AppSizes.fontM,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          // Cost price (editable, can override default)
          Expanded(
            flex: 1,
            child: TextField(
              controller: costPriceController,
              decoration: InputDecoration(
                hintText: '0.00',
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                errorStyle: const TextStyle(fontSize: 0),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: TextStyle(
                fontSize: AppSizes.fontM,
                color: (double.tryParse(costPriceController.text) ?? 0) <= 0
                    ? AppColors.error
                    : AppColors.textPrimary,
              ),
            ),
          ),
          // Quantity (editable)
          Expanded(
            flex: 1,
            child: TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                hintText: '1',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: AppSizes.fontM,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Subtotal (calculated)
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(
                '₹${getSubtotal().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: AppSizes.fontM,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          // CGST% (editable, 0-100, auto-clamped)
          Expanded(
            flex: 1,
            child: TextField(
              controller: cgstController,
              decoration: const InputDecoration(
                hintText: '0',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: TextStyle(
                fontSize: AppSizes.fontS,
                color: (double.tryParse(cgstController.text) ?? 0) > 100
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
            ),
          ),
          // SGST% (editable, 0-100, auto-clamped)
          Expanded(
            flex: 1,
            child: TextField(
              controller: sgstController,
              decoration: const InputDecoration(
                hintText: '0',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: TextStyle(
                fontSize: AppSizes.fontS,
                color: (double.tryParse(sgstController.text) ?? 0) > 100
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
            ),
          ),
          // IGST% (editable, 0-100, auto-clamped)
          Expanded(
            flex: 1,
            child: TextField(
              controller: igstController,
              decoration: const InputDecoration(
                hintText: '0',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: TextStyle(
                fontSize: AppSizes.fontS,
                color: (double.tryParse(igstController.text) ?? 0) > 100
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
            ),
          ),
          // UTGST% (editable, 0-100, auto-clamped)
          Expanded(
            flex: 1,
            child: TextField(
              controller: utgstController,
              decoration: const InputDecoration(
                hintText: '0',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: TextStyle(
                fontSize: AppSizes.fontS,
                color: (double.tryParse(utgstController.text) ?? 0) > 100
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
            ),
          ),
          // Tax amount (calculated)
          Expanded(
            flex: 1,
            child: Text(
              '₹${getTaxAmount().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: AppSizes.fontM,
                color: AppColors.warning,
              ),
            ),
          ),
          // Total amount (calculated)
          Expanded(
            flex: 1,
            child: Text(
              '₹${getTotalAmount().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: AppSizes.fontM,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
          // Delete button
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.delete, size: 18),
              color: AppColors.error,
              onPressed: () => onDelete(this),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  void dispose() {
    productController.dispose();
    costPriceController.dispose();
    quantityController.dispose();
    cgstController.dispose();
    sgstController.dispose();
    igstController.dispose();
  }
}
