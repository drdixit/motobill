import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/apis/parsed_invoice.dart';
import '../model/services/invoice_parser_service.dart';
import '../model/vendor.dart';
import '../model/product.dart';
import '../model/purchase.dart';
import '../repository/vendor_repository.dart';
import '../repository/product_repository.dart';
import '../repository/purchase_repository.dart';
import '../repository/hsn_code_repository.dart';
import '../core/providers/database_provider.dart';

// Repository providers
final _vendorRepoProvider = FutureProvider<VendorRepository>((ref) async {
  final db = await ref.watch(databaseProvider);
  return VendorRepository(db);
});

final _productRepoProvider = FutureProvider<ProductRepository>((ref) async {
  final db = await ref.watch(databaseProvider);
  return ProductRepository(db);
});

final _purchaseRepoProvider = FutureProvider<PurchaseRepository>((ref) async {
  final db = await ref.watch(databaseProvider);
  return PurchaseRepository(db);
});

final _hsnRepoProvider = FutureProvider<HsnCodeRepository>((ref) async {
  final db = await ref.watch(databaseProvider);
  return HsnCodeRepository(db);
});

// State for purchase bill automation
class PurchaseBillAutomationState {
  final bool isLoading;
  final ParsedInvoice? parsedInvoice;
  final String? error;
  final Vendor? existingVendor;
  final int? selectedVendorId; // Manually selected vendor
  final Map<int, int?> productMatches; // index -> product_id
  final bool isCreating;
  final String? successMessage;
  final bool isBillTaxable; // Global taxable flag for entire bill
  final List<Vendor> availableVendors; // For vendor selection
  final List<Product> availableProducts; // For product selection
  final List<ParsedInvoiceItem> unmatchedItems; // Items not found in database

  PurchaseBillAutomationState({
    this.isLoading = false,
    this.parsedInvoice,
    this.error,
    this.existingVendor,
    this.selectedVendorId,
    this.productMatches = const {},
    this.isCreating = false,
    this.successMessage,
    this.isBillTaxable = true,
    this.availableVendors = const [],
    this.availableProducts = const [],
    this.unmatchedItems = const [],
  });

  PurchaseBillAutomationState copyWith({
    bool? isLoading,
    ParsedInvoice? parsedInvoice,
    String? error,
    Vendor? existingVendor,
    int? selectedVendorId,
    Map<int, int?>? productMatches,
    bool? isCreating,
    String? successMessage,
    bool? isBillTaxable,
    List<Vendor>? availableVendors,
    List<Product>? availableProducts,
    List<ParsedInvoiceItem>? unmatchedItems,
  }) {
    return PurchaseBillAutomationState(
      isLoading: isLoading ?? this.isLoading,
      parsedInvoice: parsedInvoice ?? this.parsedInvoice,
      error: error,
      existingVendor: existingVendor ?? this.existingVendor,
      selectedVendorId: selectedVendorId ?? this.selectedVendorId,
      productMatches: productMatches ?? this.productMatches,
      isCreating: isCreating ?? this.isCreating,
      successMessage: successMessage,
      isBillTaxable: isBillTaxable ?? this.isBillTaxable,
      availableVendors: availableVendors ?? this.availableVendors,
      availableProducts: availableProducts ?? this.availableProducts,
      unmatchedItems: unmatchedItems ?? this.unmatchedItems,
    );
  }
}

class PurchaseBillAutomationViewModel
    extends StateNotifier<PurchaseBillAutomationState> {
  final VendorRepository? _vendorRepository;
  final ProductRepository? _productRepository;
  final PurchaseRepository? _purchaseRepository;
  final HsnCodeRepository? _hsnRepository;

  PurchaseBillAutomationViewModel(
    this._vendorRepository,
    this._productRepository,
    this._purchaseRepository,
    this._hsnRepository,
  ) : super(PurchaseBillAutomationState());

  // Constructor for loading state
  PurchaseBillAutomationViewModel._loading()
    : _vendorRepository = null,
      _productRepository = null,
      _purchaseRepository = null,
      _hsnRepository = null,
      super(PurchaseBillAutomationState());

  /// Parse API response and prepare data
  Future<void> parseInvoiceResponse(String jsonResponse) async {
    if (_vendorRepository == null ||
        _productRepository == null ||
        _purchaseRepository == null ||
        _hsnRepository == null)
      return;

    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    // Allow UI to update before starting heavy work
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // Check if response is empty
      if (jsonResponse.trim().isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'API response is empty',
        );
        return;
      }

      // Parse invoice
      final parsed = InvoiceParserService.parseInvoiceResponse(jsonResponse);

      if (parsed == null) {
        state = state.copyWith(
          isLoading: false,
          error:
              'Failed to parse invoice response. Please check if the response contains valid invoice data.',
        );
        return;
      }

      // Check if invoice has items
      if (parsed.items.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'No line items found in the invoice',
        );
        return;
      }

      // Look up vendor by GSTIN
      final vendor = await _vendorRepository.getVendorByGSTIN(
        parsed.vendor.gstin,
      );

      // Look up products by part number and filter items
      final productMatches = <int, int?>{};
      final matchedItems = <ParsedInvoiceItem>[];
      final unmatchedItems = <ParsedInvoiceItem>[];

      print('\n=== Product Matching Started ===');
      print('Total items in invoice: ${parsed.items.length}');

      for (int i = 0; i < parsed.items.length; i++) {
        final item = parsed.items[i];
        print('\nChecking item ${i + 1}: "${item.partNumber}"');

        final product = await _productRepository!.getProductByPartNumber(
          item.partNumber,
        );

        if (product != null) {
          // Product found - enrich with database HSN code if invoice HSN is empty
          print(
            '  ✓ MATCHED - Found product ID: ${product.id}, Name: ${product.name}',
          );

          String finalHsnCode = item.hsnCode;
          if (finalHsnCode.isEmpty || finalHsnCode.trim().isEmpty) {
            // Get HSN code from database
            final hsnCodeObj = await _hsnRepository!.getHsnCodeById(
              product.hsnCodeId,
            );
            if (hsnCodeObj != null) {
              finalHsnCode = hsnCodeObj.code;
              print('  → Using HSN code from database: $finalHsnCode');
            }
          }

          // Create enriched item with database HSN code
          final enrichedItem = ParsedInvoiceItem(
            partNumber: item.partNumber,
            description: item.description,
            hsnCode: finalHsnCode,
            quantity: item.quantity,
            uqc: item.uqc,
            rate: item.rate,
            cgstRate: item.cgstRate,
            sgstRate: item.sgstRate,
            cgstAmount: item.cgstAmount,
            sgstAmount: item.sgstAmount,
            totalAmount: item.totalAmount,
            isApproved: false,
            isTaxable: item.isTaxable,
          );

          productMatches[matchedItems.length] = product.id;
          matchedItems.add(enrichedItem);
        } else {
          // Product not found - add to unmatched items
          print(
            '  ✗ NOT FOUND - No product with part_number="${item.partNumber}" in database',
          );
          unmatchedItems.add(item);
        }
      }

      print('\n=== Product Matching Summary ===');
      print('Matched: ${matchedItems.length} items');
      print('Unmatched: ${unmatchedItems.length} items');
      print('================================\n');

      // Create new parsed invoice with only matched items
      final filteredInvoice = ParsedInvoice(
        invoiceNumber: parsed.invoiceNumber,
        invoiceDate: parsed.invoiceDate,
        vendor: parsed.vendor,
        items: matchedItems,
        subtotal: parsed.subtotal,
        cgstAmount: parsed.cgstAmount,
        sgstAmount: parsed.sgstAmount,
        totalAmount: parsed.totalAmount,
      );

      // Only load vendors if no vendor found (lazy loading)
      List<Vendor> availableVendors = [];
      if (vendor == null) {
        availableVendors = await _vendorRepository.getAllVendors();
      }

      state = state.copyWith(
        isLoading: false,
        parsedInvoice: filteredInvoice,
        existingVendor: vendor,
        selectedVendorId: vendor?.id,
        productMatches: productMatches,
        availableVendors: availableVendors,
        availableProducts: [], // Don't load all products - too slow
        unmatchedItems: unmatchedItems, // Store unmatched items
      );

      // Show info about unmatched items
      if (unmatchedItems.isNotEmpty) {
        print(
          'INFO: ${unmatchedItems.length} items not found in product database and will be excluded from bill:',
        );
        for (final item in unmatchedItems) {
          print('  - ${item.partNumber}: ${item.description}');
        }
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error parsing invoice: $e',
      );
    }
  }

  /// Toggle approval for an item
  void toggleItemApproval(int index) {
    if (state.parsedInvoice == null) return;

    final items = List<ParsedInvoiceItem>.from(state.parsedInvoice!.items);
    items[index] = items[index].copyWith(isApproved: !items[index].isApproved);

    final updatedInvoice = _recalculateTotals(items);
    state = state.copyWith(parsedInvoice: updatedInvoice);
  }

  /// Select all valid products (approve all items)
  void selectAllValidProducts() {
    if (state.parsedInvoice == null) return;

    final items = state.parsedInvoice!.items
        .map((item) => item.copyWith(isApproved: true))
        .toList();

    final updatedInvoice = _recalculateTotals(items);
    state = state.copyWith(parsedInvoice: updatedInvoice);
  }

  /// Recalculate totals based on approved items
  ParsedInvoice _recalculateTotals(List<ParsedInvoiceItem> items) {
    double subtotal = 0;
    double cgstAmount = 0;
    double sgstAmount = 0;
    double totalAmount = 0;

    for (final item in items) {
      if (item.isApproved) {
        // Calculate item base amount (quantity * rate)
        final itemBaseAmount = item.quantity * item.rate;
        subtotal += itemBaseAmount;
        cgstAmount += item.cgstAmount;
        sgstAmount += item.sgstAmount;
        totalAmount += item.totalAmount;
      }
    }

    return ParsedInvoice(
      invoiceNumber: state.parsedInvoice!.invoiceNumber,
      invoiceDate: state.parsedInvoice!.invoiceDate,
      vendor: state.parsedInvoice!.vendor,
      items: items,
      subtotal: subtotal,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      totalAmount: totalAmount,
    );
  }

  /// Toggle bill taxable flag (applies to entire bill)
  void toggleBillTaxable() {
    state = state.copyWith(isBillTaxable: !state.isBillTaxable);
  }

  /// Set vendor manually
  void setVendor(int vendorId) {
    state = state.copyWith(selectedVendorId: vendorId);
  }

  /// Set product for a specific item
  void setProductForItem(int index, int productId) {
    final updatedMatches = Map<int, int?>.from(state.productMatches);
    updatedMatches[index] = productId;
    state = state.copyWith(productMatches: updatedMatches);
  }

  /// Toggle taxable flag for an item (DEPRECATED - use toggleBillTaxable instead)
  @Deprecated('Use toggleBillTaxable() for entire bill')
  void toggleItemTaxable(int index) {
    if (state.parsedInvoice == null) return;

    final items = List<ParsedInvoiceItem>.from(state.parsedInvoice!.items);
    items[index] = items[index].copyWith(isTaxable: !items[index].isTaxable);

    state = state.copyWith(
      parsedInvoice: ParsedInvoice(
        invoiceNumber: state.parsedInvoice!.invoiceNumber,
        invoiceDate: state.parsedInvoice!.invoiceDate,
        vendor: state.parsedInvoice!.vendor,
        items: items,
        subtotal: state.parsedInvoice!.subtotal,
        cgstAmount: state.parsedInvoice!.cgstAmount,
        sgstAmount: state.parsedInvoice!.sgstAmount,
        totalAmount: state.parsedInvoice!.totalAmount,
      ),
    );
  }

  /// Create purchase bill from approved items
  Future<void> createPurchaseBill() async {
    if (state.parsedInvoice == null) {
      state = state.copyWith(error: 'Missing invoice data');
      return;
    }

    // Check vendor selection
    if (state.selectedVendorId == null) {
      state = state.copyWith(
        error: 'Please select a vendor before creating the purchase bill',
      );
      return;
    }

    // Set loading state
    state = state.copyWith(isCreating: true, error: null);

    // Allow UI to update before starting heavy computation
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final parsed = state.parsedInvoice!;
      final vendorId = state.selectedVendorId!;

      // Filter approved items only
      final approvedItems = <ParsedInvoiceItem>[];
      final approvedIndices = <int>[];

      for (int i = 0; i < parsed.items.length; i++) {
        if (parsed.items[i].isApproved) {
          approvedItems.add(parsed.items[i]);
          approvedIndices.add(i);
        }
      }

      if (approvedItems.isEmpty) {
        state = state.copyWith(
          isCreating: false,
          error: 'No items approved. Please approve at least one item.',
        );
        return;
      }

      // All items in the list already have product matches (filtered during parse)
      // No need to check for missing products

      // Generate purchase number
      final purchaseNumber = await _purchaseRepository!
          .generatePurchaseNumber();

      // Parse invoice date
      DateTime? invoiceDate;
      try {
        // Try parsing different date formats
        final dateStr = parsed.invoiceDate;
        if (dateStr.contains('-')) {
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final monthMap = {
              'Jan': 1,
              'Feb': 2,
              'Mar': 3,
              'Apr': 4,
              'May': 5,
              'Jun': 6,
              'Jul': 7,
              'Aug': 8,
              'Sep': 9,
              'Oct': 10,
              'Nov': 11,
              'Dec': 12,
            };
            final month = monthMap[parts[1]] ?? 1;
            final year = 2000 + int.parse(parts[2]);
            invoiceDate = DateTime(year, month, day);
          }
        }
      } catch (e) {
        invoiceDate = DateTime.now();
      }

      // Calculate totals for approved items
      double subtotal = 0;
      double taxAmount = 0;
      for (final item in approvedItems) {
        final baseAmount =
            item.totalAmount / (1 + ((item.cgstRate + item.sgstRate) / 100));
        subtotal += baseAmount;
        taxAmount += item.cgstAmount + item.sgstAmount;
      }
      final totalAmount = subtotal + taxAmount;

      // Create purchase
      final purchase = Purchase(
        purchaseNumber: purchaseNumber,
        purchaseReferenceNumber: parsed.invoiceNumber,
        purchaseReferenceDate: invoiceDate,
        vendorId: vendorId,
        subtotal: subtotal,
        taxAmount: taxAmount,
        totalAmount: totalAmount,
        isTaxableBill: state.isBillTaxable,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create purchase items
      final purchaseItems = <PurchaseItem>[];
      final taxableFlags = <bool>[];

      for (final index in approvedIndices) {
        final item = parsed.items[index];
        final productId = state.productMatches[index]!;

        final baseAmount =
            item.totalAmount / (1 + ((item.cgstRate + item.sgstRate) / 100));

        purchaseItems.add(
          PurchaseItem(
            productId: productId,
            productName: item.description,
            partNumber: item.partNumber,
            hsnCode: item.hsnCode,
            uqcCode: item.uqc,
            costPrice: item.rate,
            quantity: item.quantity,
            subtotal: baseAmount,
            cgstRate: item.cgstRate,
            sgstRate: item.sgstRate,
            igstAmount: 0.0,
            utgstAmount: 0.0,
            cgstAmount: item.cgstAmount,
            sgstAmount: item.sgstAmount,
            taxAmount: item.cgstAmount + item.sgstAmount,
            totalAmount: item.totalAmount,
          ),
        );

        // Use bill-level taxable flag for all items
        taxableFlags.add(state.isBillTaxable);
      }

      // Create purchase with items (this is the heavy operation)
      await _purchaseRepository.createAutomatedPurchase(
        purchase,
        purchaseItems,
        taxableFlags,
      );

      state = state.copyWith(
        isCreating: false,
        successMessage: 'Purchase bill created successfully! ($purchaseNumber)',
      );
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: 'Error creating purchase bill: $e',
      );
    }
  }

  /// Clear state
  void clearState() {
    state = PurchaseBillAutomationState();
  }
}

// Provider
final purchaseBillAutomationViewModelProvider =
    StateNotifierProvider.autoDispose<
      PurchaseBillAutomationViewModel,
      PurchaseBillAutomationState
    >((ref) {
      final vendorRepoAsync = ref.watch(_vendorRepoProvider);
      final productRepoAsync = ref.watch(_productRepoProvider);
      final purchaseRepoAsync = ref.watch(_purchaseRepoProvider);
      final hsnRepoAsync = ref.watch(_hsnRepoProvider);

      // All repos must be loaded
      if (vendorRepoAsync.isLoading ||
          productRepoAsync.isLoading ||
          purchaseRepoAsync.isLoading ||
          hsnRepoAsync.isLoading) {
        return PurchaseBillAutomationViewModel._loading();
      }

      if (vendorRepoAsync.hasError ||
          productRepoAsync.hasError ||
          purchaseRepoAsync.hasError ||
          hsnRepoAsync.hasError) {
        return PurchaseBillAutomationViewModel._loading();
      }

      return PurchaseBillAutomationViewModel(
        vendorRepoAsync.value,
        productRepoAsync.value,
        purchaseRepoAsync.value,
        hsnRepoAsync.value,
      );
    });
