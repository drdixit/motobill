import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/pos_product.dart';
import '../model/bill.dart';
import '../model/customer.dart';
import '../model/main_category.dart';
import '../model/sub_category.dart';
import '../model/manufacturer.dart';
import '../repository/pos_repository.dart';
import '../repository/customer_repository.dart';
import '../repository/bill_repository.dart';
import '../core/providers/database_provider.dart';
import '../core/providers/repository_provider.dart';

final posRepositoryProvider = Provider<PosRepository>((ref) {
  throw UnimplementedError('Use posRepositoryFutureProvider instead');
});

final posRepositoryFutureProvider = FutureProvider<PosRepository>((ref) async {
  final db = await ref.watch(databaseProvider);
  return PosRepository(db);
});

final customerRepositoryFutureProvider = FutureProvider<CustomerRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return CustomerRepository(db);
});

class PosState {
  final List<PosProduct> allProducts;
  final List<PosProduct> filteredProducts;
  final List<BillItem> cartItems;
  final List<MainCategory> mainCategories;
  final List<SubCategory> subCategories;
  final List<Manufacturer> manufacturers;
  final List<Customer> customers;
  final Customer? selectedCustomer;
  final String? companyGstNumber;
  final Map<int, double> lastCustomPrices; // productId -> last price with tax
  final int? selectedMainCategoryId;
  final int? selectedSubCategoryId;
  final int? selectedManufacturerId;
  final String searchQuery;
  final bool isLoading;
  final String? error;
  final bool showCheckoutConfirmation; // Always true by default on app launch
  final bool
  useTaxableStock; // false = use non-taxable stock, true = use taxable stock

  PosState({
    this.allProducts = const [],
    this.filteredProducts = const [],
    this.cartItems = const [],
    this.mainCategories = const [],
    this.subCategories = const [],
    this.manufacturers = const [],
    this.customers = const [],
    this.selectedCustomer,
    this.companyGstNumber,
    this.lastCustomPrices = const {},
    this.selectedMainCategoryId,
    this.selectedSubCategoryId,
    this.selectedManufacturerId,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
    this.showCheckoutConfirmation = true, // Default to true
    this.useTaxableStock = false, // Default to false (use non-taxable stock)
  });

  double get subtotal {
    return cartItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get taxAmount {
    return cartItems.fold(0.0, (sum, item) => sum + item.taxAmount);
  }

  double get totalAmount {
    return cartItems.fold(0.0, (sum, item) => sum + item.totalAmount);
  }

  int get totalItems {
    return cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  PosState copyWith({
    List<PosProduct>? allProducts,
    List<PosProduct>? filteredProducts,
    List<BillItem>? cartItems,
    List<MainCategory>? mainCategories,
    List<SubCategory>? subCategories,
    List<Manufacturer>? manufacturers,
    List<Customer>? customers,
    Customer? selectedCustomer,
    bool clearCustomer = false,
    String? companyGstNumber,
    Map<int, double>? lastCustomPrices,
    int? selectedMainCategoryId,
    bool clearMainCategory = false,
    int? selectedSubCategoryId,
    bool clearSubCategory = false,
    int? selectedManufacturerId,
    bool clearManufacturer = false,
    String? searchQuery,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? showCheckoutConfirmation,
    bool? useTaxableStock,
  }) {
    return PosState(
      allProducts: allProducts ?? this.allProducts,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      cartItems: cartItems ?? this.cartItems,
      mainCategories: mainCategories ?? this.mainCategories,
      subCategories: subCategories ?? this.subCategories,
      manufacturers: manufacturers ?? this.manufacturers,
      customers: customers ?? this.customers,
      selectedCustomer: clearCustomer
          ? null
          : (selectedCustomer ?? this.selectedCustomer),
      lastCustomPrices: lastCustomPrices ?? this.lastCustomPrices,
      selectedMainCategoryId: clearMainCategory
          ? null
          : (selectedMainCategoryId ?? this.selectedMainCategoryId),
      selectedSubCategoryId: clearSubCategory
          ? null
          : (selectedSubCategoryId ?? this.selectedSubCategoryId),
      selectedManufacturerId: clearManufacturer
          ? null
          : (selectedManufacturerId ?? this.selectedManufacturerId),
      companyGstNumber: companyGstNumber ?? this.companyGstNumber,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      showCheckoutConfirmation:
          showCheckoutConfirmation ?? this.showCheckoutConfirmation,
      useTaxableStock: useTaxableStock ?? this.useTaxableStock,
    );
  }
}

class PosViewModel extends StateNotifier<PosState> {
  final PosRepository? _repository;
  final CustomerRepository? _customerRepository;
  final BillRepository? _billRepository;

  PosViewModel(
    PosRepository repository,
    CustomerRepository customerRepository,
    BillRepository billRepository,
  ) : _repository = repository,
      _customerRepository = customerRepository,
      _billRepository = billRepository,
      super(PosState()) {
    loadInitialData();
  }

  // Loading constructor for when repository isn't ready yet
  PosViewModel._loading()
    : _repository = null,
      _customerRepository = null,
      _billRepository = null,
      super(PosState(isLoading: true));

  Future<void> loadInitialData() async {
    if (_repository == null || _customerRepository == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final mainCategories = await _repository.getAllMainCategories();
      final manufacturers = await _repository.getAllManufacturers();
      final products = await _repository.getProductsForPos();
      final customers = await _customerRepository.getAllCustomers();

      // Fetch company GST number
      String? companyGst;
      try {
        final companyInfo = await _repository.getCompanyGstNumber();
        companyGst = companyInfo;
      } catch (e) {
        // Company GST not found, will default to CGST+SGST
        companyGst = null;
      }

      // Debug: Check if Air Filter product has GST rates
      final airFilter = products
          .where((p) => p.name.contains('Air Filter'))
          .firstOrNull;
      if (airFilter != null) {
        print('\n=== PRODUCTS LOADED ===');
        print('Air Filter Product: ${airFilter.name}');
        print('  CGST: ${airFilter.cgstRate}%');
        print('  SGST: ${airFilter.sgstRate}%');
        print('  IGST: ${airFilter.igstRate}%');
        print('========================\n');
      }

      state = state.copyWith(
        mainCategories: mainCategories,
        manufacturers: manufacturers,
        allProducts: products,
        filteredProducts: products,
        customers: customers,
        companyGstNumber: companyGst,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load data: $e',
      );
    }
  }

  Future<void> selectMainCategory(int? categoryId) async {
    if (_repository == null) return;

    // Allow clicking the same category to deselect it
    if (categoryId == state.selectedMainCategoryId && categoryId != null) {
      categoryId = null;
    }

    state = state.copyWith(
      selectedMainCategoryId: categoryId,
      clearMainCategory: categoryId == null,
      clearSubCategory: true,
    );

    try {
      List<SubCategory> subCategories = [];
      if (categoryId != null) {
        subCategories = await _repository.getSubCategoriesByMainCategory(
          categoryId,
        );
      }

      state = state.copyWith(subCategories: subCategories);

      // Apply filters in-memory (no database call)
      _applyFiltersInMemory();
    } catch (e) {
      state = state.copyWith(error: 'Failed to load sub categories: $e');
    }
  }

  void selectSubCategory(int? subCategoryId) {
    // Allow clicking the same sub-category to deselect it
    if (subCategoryId == state.selectedSubCategoryId && subCategoryId != null) {
      subCategoryId = null;
    }

    state = state.copyWith(
      selectedSubCategoryId: subCategoryId,
      clearSubCategory: subCategoryId == null,
    );
    // Apply filters in-memory (no database call)
    _applyFiltersInMemory();
  }

  void selectManufacturer(int? manufacturerId) {
    // Allow clicking the same manufacturer to deselect it
    if (manufacturerId == state.selectedManufacturerId &&
        manufacturerId != null) {
      manufacturerId = null;
    }

    state = state.copyWith(
      selectedManufacturerId: manufacturerId,
      clearManufacturer: manufacturerId == null,
    );
    // Apply filters in-memory (no database call)
    _applyFiltersInMemory();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    // Apply filters in-memory (no database call)
    _applyFiltersInMemory();
  }

  void clearFilters() {
    state = state.copyWith(
      clearMainCategory: true,
      clearSubCategory: true,
      clearManufacturer: true,
      searchQuery: '',
      subCategories: [],
    );
    // Apply filters in-memory (no database call)
    _applyFiltersInMemory();
  }

  /// Fuzzy search helper that checks if searchText matches targetText
  /// Returns true if all characters in searchText appear in targetText in order
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

  /// Check if product matches search query with fuzzy matching
  bool _matchesSearchQuery(PosProduct product, String query) {
    if (query.isEmpty) return true;

    // Search in product name
    if (_fuzzyMatch(query, product.name)) return true;

    // Search in part number (if exists)
    if (product.partNumber != null && _fuzzyMatch(query, product.partNumber!)) {
      return true;
    }

    // Search in description (if exists)
    if (product.description != null &&
        _fuzzyMatch(query, product.description!)) {
      return true;
    }

    return false;
  }

  /// Apply all filters (category, manufacturer, search) in-memory
  /// This method does NOT query the database - it filters allProducts in-memory
  void _applyFiltersInMemory() {
    // Start with all products
    var filteredProducts = state.allProducts;

    // Apply main category filter
    if (state.selectedMainCategoryId != null) {
      filteredProducts = filteredProducts.where((product) {
        // Check if product belongs to selected main category via sub-category
        return state.subCategories.any(
          (sub) =>
              sub.mainCategoryId == state.selectedMainCategoryId &&
              sub.id == product.subCategoryId,
        );
      }).toList();
    }

    // Apply sub-category filter
    if (state.selectedSubCategoryId != null) {
      filteredProducts = filteredProducts.where((product) {
        return product.subCategoryId == state.selectedSubCategoryId;
      }).toList();
    }

    // Apply manufacturer filter
    if (state.selectedManufacturerId != null) {
      filteredProducts = filteredProducts.where((product) {
        return product.manufacturerId == state.selectedManufacturerId;
      }).toList();
    }

    // Apply search query filter
    if (state.searchQuery.isNotEmpty) {
      filteredProducts = filteredProducts.where((product) {
        return _matchesSearchQuery(product, state.searchQuery);
      }).toList();
    }

    // Update state with filtered products
    state = state.copyWith(filteredProducts: filteredProducts);
  }

  void addToCart(PosProduct product) {
    final existingIndex = state.cartItems.indexWhere(
      (item) => item.productId == product.id,
    );

    List<BillItem> updatedCart;

    if (existingIndex >= 0) {
      final existingItem = state.cartItems[existingIndex];
      final newQuantity = existingItem.quantity + 1;

      // Check available stock based on bill type
      final availableStock = product.getAvailableStock(
        isTaxableBill: state.useTaxableStock,
      );

      // Validate stock unless negative_allow is enabled
      if (!product.negativeAllow && newQuantity > availableStock) {
        // Stock validation failed - show error
        state = state.copyWith(
          error: state.useTaxableStock
              ? 'Insufficient taxable stock for ${product.name}. Available: $availableStock'
              : 'Insufficient stock for ${product.name}. Available: $availableStock (${product.taxableStock} taxable + ${product.nonTaxableStock} non-taxable)',
        );
        return;
      }

      final updatedItem = _createBillItem(
        product,
        newQuantity,
        existingItem.sellingPrice,
        state.selectedCustomer,
      );

      updatedCart = List.from(state.cartItems);
      updatedCart[existingIndex] = updatedItem;
    } else {
      // Check available stock for new item
      final availableStock = product.getAvailableStock(
        isTaxableBill: state.useTaxableStock,
      );

      // Validate stock unless negative_allow is enabled
      if (!product.negativeAllow && availableStock < 1) {
        // Stock validation failed - show error
        state = state.copyWith(
          error: state.useTaxableStock
              ? 'Insufficient taxable stock for ${product.name}. Available: $availableStock'
              : 'Insufficient stock for ${product.name}. Available: $availableStock (${product.taxableStock} taxable + ${product.nonTaxableStock} non-taxable)',
        );
        return;
      }

      final newItem = _createBillItem(product, 1, null, state.selectedCustomer);
      updatedCart = [...state.cartItems, newItem];
    }

    state = state.copyWith(cartItems: updatedCart);
  }

  void updateCartItemQuantity(int productId, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(productId);
      return;
    }

    final product = state.allProducts.firstWhere((p) => p.id == productId);

    // Check available stock based on bill type
    final availableStock = product.getAvailableStock(
      isTaxableBill: state.useTaxableStock,
    );

    // Validate stock unless negative_allow is enabled
    if (!product.negativeAllow && newQuantity > availableStock) {
      // Stock validation failed - show error
      state = state.copyWith(
        error: state.useTaxableStock
            ? 'Insufficient taxable stock for ${product.name}. Available: $availableStock'
            : 'Insufficient stock for ${product.name}. Available: $availableStock (${product.taxableStock} taxable + ${product.nonTaxableStock} non-taxable)',
      );
      return;
    }

    final updatedCart = state.cartItems.map((item) {
      if (item.productId == productId) {
        return _createBillItem(
          product,
          newQuantity,
          item.sellingPrice,
          state.selectedCustomer,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(cartItems: updatedCart);
  }

  void updateCartItemPrice(int productId, double newPrice) {
    if (newPrice <= 0) return;

    final updatedCart = state.cartItems.map((item) {
      if (item.productId == productId) {
        final product = state.allProducts.firstWhere((p) => p.id == productId);
        return _createBillItem(
          product,
          item.quantity,
          newPrice,
          state.selectedCustomer,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(cartItems: updatedCart);
  }

  void updateCartItemTotal(int productId, double newSubtotal) {
    if (newSubtotal <= 0) return;

    final updatedCart = state.cartItems.map((item) {
      if (item.productId == productId) {
        final product = state.allProducts.firstWhere((p) => p.id == productId);

        // Calculate price from subtotal (subtotal = price * quantity)
        double calculatedPrice = newSubtotal / item.quantity;

        return _createBillItem(
          product,
          item.quantity,
          calculatedPrice,
          state.selectedCustomer,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(cartItems: updatedCart);
  }

  void removeFromCart(int productId) {
    final updatedCart = state.cartItems
        .where((item) => item.productId != productId)
        .toList();
    state = state.copyWith(cartItems: updatedCart);
  }

  void clearCart() {
    state = state.copyWith(
      cartItems: [],
      clearCustomer: true,
      lastCustomPrices: {},
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void toggleCheckoutConfirmation(bool value) {
    state = state.copyWith(showCheckoutConfirmation: value);
  }

  void toggleTaxableStock(bool value) {
    state = state.copyWith(useTaxableStock: value);
  }

  void selectCustomer(Customer? customer) async {
    print('\n=== SELECT CUSTOMER CALLED ===');
    print(
      'New Customer: ${customer?.name ?? "None"} (GST: ${customer?.gstNumber ?? "None"})',
    );
    print('Cart has ${state.cartItems.length} items');
    print('Company GST: ${state.companyGstNumber}');

    // Load last custom prices for this customer
    Map<int, double> customPrices = {};
    if (customer != null && customer.id != null && _repository != null) {
      try {
        final productIds = state.allProducts.map((p) => p.id).toList();
        customPrices = await _repository.getLastCustomPrices(
          customer.id!,
          productIds,
        );
        print('Loaded ${customPrices.length} custom prices for customer');
      } catch (e) {
        print('Failed to load custom prices: $e');
      }
    }

    // Recalculate all cart items with new GST logic when customer changes
    if (state.cartItems.isNotEmpty) {
      final updatedCart = state.cartItems.map((item) {
        final product = state.allProducts.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => state.allProducts.first,
        );
        return _createBillItem(
          product,
          item.quantity,
          item.sellingPrice,
          customer,
        );
      }).toList();

      state = state.copyWith(
        selectedCustomer: customer,
        clearCustomer: customer == null,
        cartItems: updatedCart,
        lastCustomPrices: customPrices,
      );
    } else {
      state = state.copyWith(
        selectedCustomer: customer,
        clearCustomer: customer == null,
        lastCustomPrices: customPrices,
      );
    }
  }

  Future<void> refreshCustomersAndSelect(int customerId) async {
    if (_customerRepository == null) return;

    try {
      // Refresh customer list
      final customers = await _customerRepository.getAllCustomers();

      // Find and select the newly created customer
      final newCustomer = customers.firstWhere((c) => c.id == customerId);

      // Update state with new customer list and select the new customer
      state = state.copyWith(customers: customers);
      selectCustomer(newCustomer);
    } catch (e) {
      print('Failed to refresh customers: $e');
    }
  }

  void addToCartWithCustomPrice(PosProduct product, double customPrice) {
    final productWithCustomPrice = PosProduct(
      id: product.id,
      name: product.name,
      partNumber: product.partNumber,
      description: product.description,
      hsnCode: product.hsnCode,
      uqcCode: product.uqcCode,
      hsnCodeId: product.hsnCodeId,
      uqcId: product.uqcId,
      costPrice: product.costPrice,
      sellingPrice: customPrice,
      imagePath: product.imagePath,
      mainCategoryName: product.mainCategoryName,
      subCategoryName: product.subCategoryName,
      subCategoryId: product.subCategoryId,
      manufacturerName: product.manufacturerName,
      manufacturerId: product.manufacturerId,
      isTaxable: product.isTaxable,
      cgstRate: product.cgstRate,
      sgstRate: product.sgstRate,
      igstRate: product.igstRate,
      utgstRate: product.utgstRate,
      stock: product.stock,
      taxableStock: product.taxableStock,
      nonTaxableStock: product.nonTaxableStock,
      negativeAllow: product.negativeAllow,
      min: product.min,
      max: product.max,
    );
    addToCart(productWithCustomPrice);
  }

  BillItem _createBillItem(
    PosProduct product,
    int quantity, [
    double? customPrice,
    Customer? customerOverride,
  ]) {
    final price = customPrice ?? product.sellingPrice;
    final subtotal = price * quantity;

    // GST calculation based on state codes
    double cgstRate = 0;
    double sgstRate = 0;
    double igstRate = 0;
    double utgstRate = 0;
    double cgstAmount = 0;
    double sgstAmount = 0;
    double igstAmount = 0;
    double utgstAmount = 0;
    double taxAmount = 0;

    if (product.isTaxable) {
      // Use customerOverride if provided, otherwise use state.selectedCustomer
      final customer = customerOverride ?? state.selectedCustomer;

      // Get UTGST rate (applies to both intra and inter-state)
      utgstRate = product.utgstRate ?? 0.0;

      // Default to CGST+SGST+UTGST (intra-state)
      bool isInterState = false;

      // Debug: Print GST information
      print('DEBUG: Product: ${product.name}');
      print('DEBUG: Customer: ${customer?.name ?? "None"}');
      print('DEBUG: Customer GST: ${customer?.gstNumber ?? "None"}');
      print('DEBUG: Company GST: ${state.companyGstNumber ?? "None"}');
      print(
        'DEBUG: Product CGST: ${product.cgstRate}, SGST: ${product.sgstRate}, IGST: ${product.igstRate}, UTGST: ${product.utgstRate}',
      );

      // Check if we should apply IGST (inter-state)
      if (customer?.gstNumber != null &&
          customer!.gstNumber!.length >= 2 &&
          state.companyGstNumber != null &&
          state.companyGstNumber!.length >= 2) {
        // Extract first 2 characters (state code) from both GST numbers
        final customerStateCode = customer.gstNumber!
            .substring(0, 2)
            .toUpperCase();
        final companyStateCode = state.companyGstNumber!
            .substring(0, 2)
            .toUpperCase();

        print('DEBUG: Customer State Code: $customerStateCode');
        print('DEBUG: Company State Code: $companyStateCode');

        // If state codes are different, it's inter-state (IGST + UTGST)
        if (customerStateCode != companyStateCode) {
          isInterState = true;
          print('DEBUG: Inter-state detected - Using IGST + UTGST');
        } else {
          print('DEBUG: Intra-state detected - Using CGST + SGST + UTGST');
        }
      }
      // If customer has no GST number, default to CGST+SGST+UTGST (intra-state)

      if (isInterState) {
        // Inter-state: Apply IGST + UTGST
        igstRate = product.igstRate ?? 0.0;
        igstAmount = subtotal * igstRate / 100;
        utgstAmount = subtotal * utgstRate / 100;
        taxAmount = igstAmount + utgstAmount;
        print(
          'DEBUG: Applying IGST + UTGST - IGST: $igstRate% (₹$igstAmount), UTGST: $utgstRate% (₹$utgstAmount), Total: ₹$taxAmount',
        );
      } else {
        // Intra-state: Apply CGST + SGST + UTGST
        cgstRate = product.cgstRate ?? 0.0;
        sgstRate = product.sgstRate ?? 0.0;
        cgstAmount = subtotal * cgstRate / 100;
        sgstAmount = subtotal * sgstRate / 100;
        utgstAmount = subtotal * utgstRate / 100;
        taxAmount = cgstAmount + sgstAmount + utgstAmount;
        print(
          'DEBUG: Applying CGST + SGST + UTGST - CGST: $cgstRate% (₹$cgstAmount), SGST: $sgstRate% (₹$sgstAmount), UTGST: $utgstRate% (₹$utgstAmount), Total: ₹$taxAmount',
        );
      }
      print(
        'DEBUG: Final - Subtotal: ₹$subtotal, Tax: ₹$taxAmount, Total: ₹${subtotal + taxAmount}\n',
      );
    }

    final totalAmount = subtotal + taxAmount;

    return BillItem(
      productId: product.id,
      productName: product.name,
      partNumber: product.partNumber,
      hsnCode: product.hsnCode,
      uqcCode: product.uqcCode,
      costPrice: product.costPrice,
      sellingPrice: price,
      quantity: quantity,
      subtotal: subtotal,
      cgstRate: cgstRate,
      sgstRate: sgstRate,
      igstRate: igstRate,
      utgstRate: utgstRate,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      igstAmount: igstAmount,
      utgstAmount: utgstAmount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
    );
  }

  // Checkout and create bill
  Future<String?> checkout() async {
    return checkoutWithPayment();
  }

  // Checkout with payment
  Future<String?> checkoutWithPayment({
    double? paymentAmount,
    String paymentMethod = 'cash',
    String? paymentNotes,
  }) async {
    if (_billRepository == null) return null;

    // Validate cart is not empty
    if (state.cartItems.isEmpty) {
      state = state.copyWith(error: 'Cart is empty');
      return null;
    }

    // Validate customer is selected
    if (state.selectedCustomer == null) {
      state = state.copyWith(error: 'Please select a customer');
      return null;
    }

    // Validate stock availability based on taxable/non-taxable setting
    for (final item in state.cartItems) {
      final product = state.allProducts.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => throw Exception('Product not found'),
      );

      // Use the helper method to get correct available stock
      final availableStock = product.getAvailableStock(
        isTaxableBill: state.useTaxableStock,
      );

      if (!product.negativeAllow && item.quantity > availableStock) {
        state = state.copyWith(
          error: state.useTaxableStock
              ? 'Insufficient taxable stock for ${product.name}. Available: $availableStock, Required: ${item.quantity}'
              : 'Insufficient stock for ${product.name}. Available: $availableStock (${product.taxableStock} taxable + ${product.nonTaxableStock} non-taxable), Required: ${item.quantity}',
        );
        return null;
      }
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Generate bill number
      final billNumber = await _billRepository.generateBillNumber();

      // Create bill object
      final bill = Bill(
        billNumber: billNumber,
        customerId: state.selectedCustomer!.id!,
        subtotal: state.subtotal,
        taxAmount: state.taxAmount,
        totalAmount: state.totalAmount,
        paidAmount: paymentAmount ?? 0,
        paymentStatus: paymentAmount == null || paymentAmount == 0
            ? 'unpaid'
            : paymentAmount >= state.totalAmount
            ? 'paid'
            : 'partial',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create bill in database (this will also update stock batches)
      final billId = await _billRepository.createBill(
        bill,
        state.cartItems,
        useTaxableStock: state.useTaxableStock,
      );

      // Add payment if amount is provided
      if (paymentAmount != null && paymentAmount > 0) {
        await _billRepository.addPayment(
          billId: billId,
          amount: paymentAmount,
          paymentMethod: paymentMethod,
          notes: paymentNotes,
        );
      }

      // Clear cart and refresh products after successful bill creation
      state = state.copyWith(cartItems: [], isLoading: false);

      // Reload products to reflect updated stock levels
      await loadInitialData();

      return billNumber;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create bill: $e',
      );
      return null;
    }
  }
}

// Provider that waits for repository and creates ViewModel
final posViewModelProvider = StateNotifierProvider<PosViewModel, PosState>((
  ref,
) {
  // Watch repository futures and get the values synchronously
  // This will cause the provider to rebuild when repositories are ready
  final repository = ref.watch(posRepositoryFutureProvider).value;
  final customerRepository = ref.watch(customerRepositoryFutureProvider).value;
  final billRepository = ref.watch(billRepositoryFutureProvider).value;

  if (repository == null ||
      customerRepository == null ||
      billRepository == null) {
    // Return a ViewModel with loading state while repositories initialize
    return PosViewModel._loading();
  }

  return PosViewModel(repository, customerRepository, billRepository);
});
