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
import '../repository/gst_rate_repository.dart';
import '../repository/company_info_repository.dart';
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

final _gstRateRepoProvider = FutureProvider<GstRateRepository>((ref) async {
  final db = await ref.watch(databaseProvider);
  return GstRateRepository(db);
});

final _companyInfoRepoProvider = FutureProvider<CompanyInfoRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return CompanyInfoRepository(db);
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
  final String? nextPurchaseNumber; // Next purchase bill number to be created

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
    this.nextPurchaseNumber,
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
    String? nextPurchaseNumber,
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
      nextPurchaseNumber: nextPurchaseNumber ?? this.nextPurchaseNumber,
    );
  }
}

class PurchaseBillAutomationViewModel
    extends StateNotifier<PurchaseBillAutomationState> {
  final VendorRepository? _vendorRepository;
  final ProductRepository? _productRepository;
  final PurchaseRepository? _purchaseRepository;
  final HsnCodeRepository? _hsnRepository;
  final GstRateRepository? _gstRateRepository;
  final CompanyInfoRepository? _companyInfoRepository;

  PurchaseBillAutomationViewModel(
    this._vendorRepository,
    this._productRepository,
    this._purchaseRepository,
    this._hsnRepository,
    this._gstRateRepository,
    this._companyInfoRepository,
  ) : super(PurchaseBillAutomationState());

  // Constructor for loading state
  PurchaseBillAutomationViewModel._loading()
    : _vendorRepository = null,
      _productRepository = null,
      _purchaseRepository = null,
      _hsnRepository = null,
      _gstRateRepository = null,
      _companyInfoRepository = null,
      super(PurchaseBillAutomationState());

  /// Helper function to extract part number from product description
  /// Examples:
  /// "TVS SIDE TRIM RH IQUBE T.GREY MAT KE22023980" -> "KE22023980"
  /// "TVS MOBILE CHARGER RADEON/JUPITER ND160350" -> "ND160350"
  /// "TVS PANEL FR TOP JUPITER 125 GREY KL2205708D" -> "KL2205708D"
  String? _extractPartNumberFromDescription(String description) {
    if (description.isEmpty) return null;

    // Pattern: Find the last word that looks like a part number
    // Part numbers typically end with alphanumeric characters
    // and are often at the end of the description
    final words = description.trim().split(RegExp(r'\s+'));

    // Check last few words for part number pattern
    // Part numbers usually have letters followed by numbers
    // or mixed alphanumeric (e.g., KE22023980, ND160350, KL2205708D)
    for (int i = words.length - 1; i >= 0 && i >= words.length - 3; i--) {
      final word = words[i].toUpperCase();

      // Check if word matches part number pattern:
      // - At least 6 characters long
      // - Contains both letters and numbers
      // - Alphanumeric only (no special chars except maybe dash/underscore)
      if (word.length >= 6 &&
          RegExp(r'^[A-Z0-9\-_]+$').hasMatch(word) &&
          RegExp(r'[A-Z]').hasMatch(word) &&
          RegExp(r'[0-9]').hasMatch(word)) {
        return word;
      }
    }

    return null;
  }

  /// Parse API response and prepare data
  Future<void> parseInvoiceResponse(String jsonResponse) async {
    if (_vendorRepository == null ||
        _productRepository == null ||
        _purchaseRepository == null ||
        _hsnRepository == null ||
        _gstRateRepository == null ||
        _companyInfoRepository == null)
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

      // Get primary company info for GST comparison
      final companyInfo = await _companyInfoRepository.getPrimaryCompanyInfo();
      final companyGstPrefix = companyInfo?.gstNumber?.substring(0, 2) ?? '';

      // Look up products by part number and filter items
      final productMatches = <int, int?>{};
      final matchedItems = <ParsedInvoiceItem>[];
      final unmatchedItems = <ParsedInvoiceItem>[];

      print('\n=== Product Matching Started ===');
      print('Total items in invoice: ${parsed.items.length}');
      print('Company GST Prefix: $companyGstPrefix');
      if (vendor != null) {
        final vendorGstPrefix = vendor.gstNumber?.substring(0, 2) ?? '';
        print('Vendor GST Prefix: $vendorGstPrefix');
      }

      for (int i = 0; i < parsed.items.length; i++) {
        final item = parsed.items[i];
        print('\nChecking item ${i + 1}: "${item.partNumber}"');

        Product? product;
        String matchedPartNumber = item.partNumber;

        // Step 1: Try direct match with part number from API response
        product = await _productRepository.getProductByPartNumber(
          item.partNumber,
        );

        if (product != null) {
          print(
            '  ✓ MATCHED (API part number) - Found product ID: ${product.id}, Name: ${product.name}, Part: ${product.partNumber}',
          );
        } else {
          // Step 2: Extract part number from description and try matching
          if (item.description.isNotEmpty) {
            final extractedPartNumber = _extractPartNumberFromDescription(
              item.description,
            );

            if (extractedPartNumber != null) {
              print(
                '  → Extracted part number from description: "$extractedPartNumber"',
              );

              // Try matching with extracted part number
              // getProductByPartNumber already does case-insensitive search
              product = await _productRepository.getProductByPartNumber(
                extractedPartNumber,
              );

              if (product != null) {
                matchedPartNumber = extractedPartNumber;
                print(
                  '  ✓ MATCHED (extracted from description) - Found product ID: ${product.id}, Name: ${product.name}, Part: ${product.partNumber}',
                );
              }
            }
          }
        }

        if (product != null) {
          // Product found - use ALL data from database
          print(
            '  ✓ MATCHED - Found product ID: ${product.id}, Name: ${product.name}',
          );

          // Get HSN code from database
          String finalHsnCode = '';
          final hsnCodeObj = await _hsnRepository.getHsnCodeById(
            product.hsnCodeId,
          );
          if (hsnCodeObj != null) {
            finalHsnCode = hsnCodeObj.code;
            print('  → Using HSN code from database: $finalHsnCode');
          }

          // Get UQC code from database - will be properly fetched in createPurchaseBill
          // For now, store product UQC ID for later use
          String finalUqcCode =
              'UQC_${product.uqcId}'; // Placeholder, will be replaced
          print('  → UQC ID from database: ${product.uqcId}');

          // Always calculate GST reverse from total (bill prices include GST)
          // Determine GST calculation method based on vendor GST prefix
          final vendorGstPrefix = vendor?.gstNumber?.substring(0, 2) ?? '';

          // Case 1: Same state (both GST prefixes match) -> CGST + SGST + UTGST
          // Case 2: Different state (GST prefixes don't match and vendor has GST) -> IGST + UTGST
          // Case 3: No vendor GST -> CGST + SGST + UTGST
          final isSameState =
              vendorGstPrefix.isNotEmpty &&
              companyGstPrefix.isNotEmpty &&
              vendorGstPrefix == companyGstPrefix;
          final useIGST =
              vendorGstPrefix.isNotEmpty &&
              companyGstPrefix.isNotEmpty &&
              vendorGstPrefix != companyGstPrefix;

          print('  → Same State: $isSameState, Use IGST: $useIGST');

          // Get GST rates from database
          final gstRate = await _gstRateRepository.getGstRateByHsnCodeId(
            product.hsnCodeId,
          );

          double finalRate;
          double finalCgstRate = 0;
          double finalSgstRate = 0;
          double finalIgstRate = 0;
          double finalUtgstRate = 0;
          double finalCgstAmount = 0;
          double finalSgstAmount = 0;
          double finalIgstAmount = 0;
          double finalUtgstAmount = 0;
          double finalTotalAmount = item.totalAmount;
          bool isPriceFromBill = item.totalAmount > 0;

          if (item.totalAmount > 0 && item.quantity > 0) {
            // Reverse calculate: Total includes GST
            if (gstRate != null) {
              finalUtgstRate = gstRate.utgst; // UTGST always applied

              if (useIGST) {
                // Case 2: Different state -> IGST + UTGST
                finalIgstRate = gstRate.igst;
                final totalGstRate = finalIgstRate + finalUtgstRate;

                // Reverse calculation: basePrice = total / (1 + totalGstRate/100)
                final baseAmount =
                    item.totalAmount / (1 + (totalGstRate / 100));
                finalRate = baseAmount / item.quantity;
                finalIgstAmount = baseAmount * (finalIgstRate / 100);
                finalUtgstAmount = baseAmount * (finalUtgstRate / 100);

                print('  → IGST: ${finalIgstRate}%, UTGST: ${finalUtgstRate}%');
                print(
                  '  → Base Amount: ₹${baseAmount.toStringAsFixed(2)}, Rate: ₹${finalRate.toStringAsFixed(2)}',
                );
              } else {
                // Case 1 & 3: Same state or No GST -> CGST + SGST + UTGST
                finalCgstRate = gstRate.cgst;
                finalSgstRate = gstRate.sgst;
                final totalGstRate =
                    finalCgstRate + finalSgstRate + finalUtgstRate;

                // Reverse calculation: basePrice = total / (1 + totalGstRate/100)
                final baseAmount =
                    item.totalAmount / (1 + (totalGstRate / 100));
                finalRate = baseAmount / item.quantity;
                finalCgstAmount = baseAmount * (finalCgstRate / 100);
                finalSgstAmount = baseAmount * (finalSgstRate / 100);
                finalUtgstAmount = baseAmount * (finalUtgstRate / 100);

                print(
                  '  → CGST: ${finalCgstRate}%, SGST: ${finalSgstRate}%, UTGST: ${finalUtgstRate}%',
                );
                print(
                  '  → Base Amount: ₹${baseAmount.toStringAsFixed(2)}, Rate: ₹${finalRate.toStringAsFixed(2)}',
                );
              }
            } else {
              // No GST rate found - assume total is base price
              finalRate = item.totalAmount / item.quantity;
              print('  → No GST rate found, treating total as base price');
            }
          } else {
            // No price in bill - use database cost price
            print(
              '  → No price in bill, using database cost price: ${product.costPrice}',
            );
            isPriceFromBill = false;
            finalRate = product.costPrice;

            if (gstRate != null) {
              finalUtgstRate = gstRate.utgst;

              if (useIGST) {
                // Case 2: IGST + UTGST
                finalIgstRate = gstRate.igst;
                final baseAmount = finalRate * item.quantity;
                finalIgstAmount = baseAmount * (finalIgstRate / 100);
                finalUtgstAmount = baseAmount * (finalUtgstRate / 100);
                finalTotalAmount =
                    baseAmount + finalIgstAmount + finalUtgstAmount;
              } else {
                // Case 1 & 3: CGST + SGST + UTGST
                finalCgstRate = gstRate.cgst;
                finalSgstRate = gstRate.sgst;
                final baseAmount = finalRate * item.quantity;
                finalCgstAmount = baseAmount * (finalCgstRate / 100);
                finalSgstAmount = baseAmount * (finalSgstRate / 100);
                finalUtgstAmount = baseAmount * (finalUtgstRate / 100);
                finalTotalAmount =
                    baseAmount +
                    finalCgstAmount +
                    finalSgstAmount +
                    finalUtgstAmount;
              }
            } else {
              finalTotalAmount = finalRate * item.quantity;
            }
          }

          // Create enriched item
          final enrichedItem = ParsedInvoiceItem(
            partNumber:
                matchedPartNumber, // Use the matched part number (API or extracted)
            description: item.description,
            hsnCode: finalHsnCode,
            quantity: item.quantity,
            uqc: finalUqcCode, // Use UQC placeholder with ID
            rate: finalRate,
            cgstRate: finalCgstRate,
            sgstRate: finalSgstRate,
            igstRate: finalIgstRate,
            utgstRate: finalUtgstRate,
            cgstAmount: finalCgstAmount,
            sgstAmount: finalSgstAmount,
            igstAmount: finalIgstAmount,
            utgstAmount: finalUtgstAmount,
            totalAmount: finalTotalAmount,
            isApproved: false,
            isTaxable: item.isTaxable,
            isPriceFromBill: isPriceFromBill,
            dbProductName: product.name,
            dbProductDescription: product.description,
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

      // Get next purchase number
      final nextPurchaseNumber = await _purchaseRepository
          .generatePurchaseNumber();

      state = state.copyWith(
        isLoading: false,
        parsedInvoice: filteredInvoice,
        existingVendor: vendor,
        selectedVendorId: vendor?.id,
        productMatches: productMatches,
        availableVendors: availableVendors,
        availableProducts: [], // Don't load all products - too slow
        unmatchedItems: unmatchedItems, // Store unmatched items
        nextPurchaseNumber: nextPurchaseNumber,
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

    final items = state.parsedInvoice!.items.map((item) {
      // Only approve items where Rate <= Total (valid entries)
      final isValid = item.rate <= item.totalAmount;
      return item.copyWith(isApproved: isValid);
    }).toList();

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
  Future<void> createPurchaseBill({
    double paymentAmount = 0,
    String paymentMethod = 'cash',
    String? paymentNotes,
  }) async {
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

      // Get selected vendor from database to check GST
      final selectedVendor = await _vendorRepository!.getVendorById(vendorId);
      if (selectedVendor == null) {
        state = state.copyWith(
          isCreating: false,
          error: 'Selected vendor not found in database',
        );
        return;
      }

      // Get primary company info for GST comparison
      final companyInfo = await _companyInfoRepository!.getPrimaryCompanyInfo();
      final companyGstPrefix = companyInfo?.gstNumber?.substring(0, 2) ?? '';
      final vendorGstPrefix = selectedVendor.gstNumber?.substring(0, 2) ?? '';

      // Determine GST calculation method
      // Case 1: Same state (both GST prefixes match) -> CGST + SGST + UTGST
      // Case 2: No vendor GST -> CGST + SGST + UTGST
      // Case 3: Different state -> IGST + UTGST
      final useIGST =
          vendorGstPrefix.isNotEmpty &&
          companyGstPrefix.isNotEmpty &&
          vendorGstPrefix != companyGstPrefix;

      print('\n=== GST Calculation for Purchase Bill ===');
      print('Company GST Prefix: $companyGstPrefix');
      print('Selected Vendor GST Prefix: $vendorGstPrefix');
      print('Use IGST: $useIGST');
      print('=========================================\n');

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

      // Recalculate GST for approved items based on selected vendor
      for (int i = 0; i < approvedItems.length; i++) {
        final item = approvedItems[i];
        final index = approvedIndices[i];

        // Get product to fetch HSN code ID
        final productId = state.productMatches[index];
        if (productId == null) continue;

        final product = await _productRepository!.getProductById(productId);
        if (product == null) continue;

        // Get GST rates from database using HSN code ID
        final gstRate = await _gstRateRepository!.getGstRateByHsnCodeId(
          product.hsnCodeId,
        );

        double cgstRate = 0;
        double sgstRate = 0;
        double igstRate = 0;
        double utgstRate = 0;

        if (gstRate != null) {
          // Determine tax type based on vendor GST
          if (useIGST) {
            // Different state: Use IGST + UTGST
            igstRate = gstRate.igst;
            utgstRate = gstRate.utgst;
          } else {
            // Same state or no vendor GST: Use CGST + SGST + UTGST
            cgstRate = gstRate.cgst;
            sgstRate = gstRate.sgst;
            utgstRate = gstRate.utgst;
          }

          // Reverse calculate base amount and tax amounts
          final totalGstRate = cgstRate + sgstRate + igstRate + utgstRate;
          final baseAmount = totalGstRate > 0
              ? item.totalAmount / (1 + (totalGstRate / 100))
              : item.totalAmount;

          final cgstAmount = (baseAmount * cgstRate) / 100;
          final sgstAmount = (baseAmount * sgstRate) / 100;
          final igstAmount = (baseAmount * igstRate) / 100;
          final utgstAmount = (baseAmount * utgstRate) / 100;

          // Calculate rate (per unit price WITHOUT tax - base price)
          final rate = item.quantity > 0
              ? baseAmount /
                    item
                        .quantity // Base price per unit (without tax)
              : 0.0;

          // Update the approved item with recalculated GST
          approvedItems[i] = ParsedInvoiceItem(
            partNumber: item.partNumber,
            description: item.description,
            hsnCode: item.hsnCode,
            uqc: item.uqc,
            quantity: item.quantity,
            rate: rate,
            cgstRate: cgstRate,
            sgstRate: sgstRate,
            igstRate: igstRate,
            utgstRate: utgstRate,
            cgstAmount: cgstAmount,
            sgstAmount: sgstAmount,
            igstAmount: igstAmount,
            utgstAmount: utgstAmount,
            totalAmount: item.totalAmount,
            isPriceFromBill: item.isPriceFromBill,
            isApproved: item.isApproved,
            dbProductName: item.dbProductName,
            dbProductDescription: item.dbProductDescription,
          );

          print(
            'Item ${item.partNumber}: Total=${item.totalAmount}, '
            'CGST=${cgstRate.toStringAsFixed(2)}%, '
            'SGST=${sgstRate.toStringAsFixed(2)}%, '
            'IGST=${igstRate.toStringAsFixed(2)}%, '
            'UTGST=${utgstRate.toStringAsFixed(2)}%',
          );
        }
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
        // Calculate base amount (without tax)
        final totalGstRate =
            item.igstRate + item.utgstRate + item.cgstRate + item.sgstRate;
        final baseAmount = totalGstRate > 0
            ? item.totalAmount / (1 + (totalGstRate / 100))
            : item.totalAmount;
        subtotal += baseAmount;
        taxAmount +=
            item.cgstAmount +
            item.sgstAmount +
            item.igstAmount +
            item.utgstAmount;
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
        paidAmount: paymentAmount,
        paymentStatus: _calculatePaymentStatus(paymentAmount, totalAmount),
        isTaxableBill: state.isBillTaxable,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create purchase items using recalculated GST values
      final purchaseItems = <PurchaseItem>[];
      final taxableFlags = <bool>[];

      for (int i = 0; i < approvedItems.length; i++) {
        final item = approvedItems[i]; // Use recalculated items
        final index = approvedIndices[i];
        final productId = state.productMatches[index]!;

        // Calculate base amount (without tax)
        final totalGstRate =
            item.igstRate + item.utgstRate + item.cgstRate + item.sgstRate;
        final baseAmount = totalGstRate > 0
            ? item.totalAmount / (1 + (totalGstRate / 100))
            : item.totalAmount;

        // Fetch UQC code from database using product
        final product = await _productRepository!.getProductById(productId);
        String uqcCode = 'PCS'; // Default fallback

        if (product != null && item.uqc.startsWith('UQC_')) {
          // UQC from database - for now use default
          // TODO: Add method to fetch UQC code from uqcs table
          uqcCode = 'PCS';
        } else if (!item.uqc.startsWith('UQC_')) {
          uqcCode = item.uqc;
        }

        purchaseItems.add(
          PurchaseItem(
            productId: productId,
            productName:
                item.dbProductName ?? item.description, // Use DB product name
            partNumber: item.partNumber,
            hsnCode: item.hsnCode,
            uqcCode: uqcCode, // Use fetched UQC code
            costPrice: item.rate,
            quantity: item.quantity,
            subtotal: baseAmount,
            cgstRate: item.cgstRate,
            sgstRate: item.sgstRate,
            igstRate: item.igstRate,
            utgstRate: item.utgstRate,
            cgstAmount: item.cgstAmount,
            sgstAmount: item.sgstAmount,
            igstAmount: item.igstAmount,
            utgstAmount: item.utgstAmount,
            taxAmount:
                item.cgstAmount +
                item.sgstAmount +
                item.igstAmount +
                item.utgstAmount,
            totalAmount: item.totalAmount,
          ),
        );

        // Use bill-level taxable flag for all items
        taxableFlags.add(state.isBillTaxable);
      }

      // Create purchase with items (this is the heavy operation)
      final purchaseId = await _purchaseRepository.createAutomatedPurchase(
        purchase,
        purchaseItems,
        taxableFlags,
      );

      // Add payment if amount is provided
      if (paymentAmount > 0) {
        await _purchaseRepository.addPayment(
          purchaseId: purchaseId,
          amount: paymentAmount,
          paymentMethod: paymentMethod,
          notes: paymentNotes,
        );
      }

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

  String _calculatePaymentStatus(double paidAmount, double totalAmount) {
    if (paidAmount <= 0) return 'unpaid';
    if (paidAmount >= totalAmount) return 'paid';
    return 'partial';
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
      final gstRateRepoAsync = ref.watch(_gstRateRepoProvider);
      final companyInfoRepoAsync = ref.watch(_companyInfoRepoProvider);

      // All repos must be loaded
      if (vendorRepoAsync.isLoading ||
          productRepoAsync.isLoading ||
          purchaseRepoAsync.isLoading ||
          hsnRepoAsync.isLoading ||
          gstRateRepoAsync.isLoading ||
          companyInfoRepoAsync.isLoading) {
        return PurchaseBillAutomationViewModel._loading();
      }

      if (vendorRepoAsync.hasError ||
          productRepoAsync.hasError ||
          purchaseRepoAsync.hasError ||
          hsnRepoAsync.hasError ||
          gstRateRepoAsync.hasError ||
          companyInfoRepoAsync.hasError) {
        return PurchaseBillAutomationViewModel._loading();
      }

      return PurchaseBillAutomationViewModel(
        vendorRepoAsync.value,
        productRepoAsync.value,
        purchaseRepoAsync.value,
        hsnRepoAsync.value,
        gstRateRepoAsync.value,
        companyInfoRepoAsync.value,
      );
    });
