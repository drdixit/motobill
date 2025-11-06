import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/apis/parsed_invoice.dart';
import '../model/services/invoice_parser_service.dart';
import '../model/vendor.dart';
import '../model/purchase.dart';
import '../repository/vendor_repository.dart';
import '../repository/product_repository.dart';
import '../repository/purchase_repository.dart';
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

// State for purchase bill automation
class PurchaseBillAutomationState {
  final bool isLoading;
  final ParsedInvoice? parsedInvoice;
  final String? error;
  final Vendor? existingVendor;
  final Map<int, int?> productMatches; // index -> product_id
  final bool isCreating;
  final String? successMessage;

  PurchaseBillAutomationState({
    this.isLoading = false,
    this.parsedInvoice,
    this.error,
    this.existingVendor,
    this.productMatches = const {},
    this.isCreating = false,
    this.successMessage,
  });

  PurchaseBillAutomationState copyWith({
    bool? isLoading,
    ParsedInvoice? parsedInvoice,
    String? error,
    Vendor? existingVendor,
    Map<int, int?>? productMatches,
    bool? isCreating,
    String? successMessage,
  }) {
    return PurchaseBillAutomationState(
      isLoading: isLoading ?? this.isLoading,
      parsedInvoice: parsedInvoice ?? this.parsedInvoice,
      error: error,
      existingVendor: existingVendor ?? this.existingVendor,
      productMatches: productMatches ?? this.productMatches,
      isCreating: isCreating ?? this.isCreating,
      successMessage: successMessage,
    );
  }
}

class PurchaseBillAutomationViewModel
    extends StateNotifier<PurchaseBillAutomationState> {
  final VendorRepository? _vendorRepository;
  final ProductRepository? _productRepository;
  final PurchaseRepository? _purchaseRepository;

  PurchaseBillAutomationViewModel(
    this._vendorRepository,
    this._productRepository,
    this._purchaseRepository,
  ) : super(PurchaseBillAutomationState());

  // Constructor for loading state
  PurchaseBillAutomationViewModel._loading()
    : _vendorRepository = null,
      _productRepository = null,
      _purchaseRepository = null,
      super(PurchaseBillAutomationState());

  /// Parse API response and prepare data
  Future<void> parseInvoiceResponse(String jsonResponse) async {
    if (_vendorRepository == null ||
        _productRepository == null ||
        _purchaseRepository == null)
      return;

    state = state.copyWith(isLoading: true, error: null, successMessage: null);

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

      // Look up products by part number
      final productMatches = <int, int?>{};
      for (int i = 0; i < parsed.items.length; i++) {
        final item = parsed.items[i];
        final product = await _productRepository.getProductByPartNumber(
          item.partNumber,
        );
        productMatches[i] = product?.id;
      }

      state = state.copyWith(
        isLoading: false,
        parsedInvoice: parsed,
        existingVendor: vendor,
        productMatches: productMatches,
      );
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

  /// Toggle taxable flag for an item
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
    if (state.parsedInvoice == null || state.existingVendor == null) {
      state = state.copyWith(error: 'Missing vendor or invoice data');
      return;
    }

    state = state.copyWith(isCreating: true, error: null);

    try {
      final parsed = state.parsedInvoice!;
      final vendor = state.existingVendor!;

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

      // Check if all approved items have product matches
      for (final index in approvedIndices) {
        if (state.productMatches[index] == null) {
          state = state.copyWith(
            isCreating: false,
            error:
                'Item "${parsed.items[index].partNumber}" not found in product database. Please create the product first.',
          );
          return;
        }
      }

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
        vendorId: vendor.id!,
        subtotal: subtotal,
        taxAmount: taxAmount,
        totalAmount: totalAmount,
        isTaxableBill: true,
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

        taxableFlags.add(item.isTaxable);
      }

      // Create purchase with items
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

      // All repos must be loaded
      if (vendorRepoAsync.isLoading ||
          productRepoAsync.isLoading ||
          purchaseRepoAsync.isLoading) {
        return PurchaseBillAutomationViewModel._loading();
      }

      if (vendorRepoAsync.hasError ||
          productRepoAsync.hasError ||
          purchaseRepoAsync.hasError) {
        return PurchaseBillAutomationViewModel._loading();
      }

      return PurchaseBillAutomationViewModel(
        vendorRepoAsync.value,
        productRepoAsync.value,
        purchaseRepoAsync.value,
      );
    });
