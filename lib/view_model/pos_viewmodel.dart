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
  final int? selectedMainCategoryId;
  final int? selectedSubCategoryId;
  final int? selectedManufacturerId;
  final String searchQuery;
  final bool isLoading;
  final String? error;

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
    this.selectedMainCategoryId,
    this.selectedSubCategoryId,
    this.selectedManufacturerId,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
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
      isLoading: true,
    );

    try {
      List<SubCategory> subCategories = [];
      if (categoryId != null) {
        subCategories = await _repository.getSubCategoriesByMainCategory(
          categoryId,
        );
      }

      state = state.copyWith(subCategories: subCategories, isLoading: false);

      await _applyFilters();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load sub categories: $e',
      );
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
    _applyFilters();
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
    _applyFilters();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  void clearFilters() {
    state = state.copyWith(
      clearMainCategory: true,
      clearSubCategory: true,
      clearManufacturer: true,
      searchQuery: '',
      subCategories: [],
    );
    _applyFilters();
  }

  Future<void> _applyFilters() async {
    if (_repository == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final products = await _repository.getProductsForPos(
        mainCategoryId: state.selectedMainCategoryId,
        subCategoryId: state.selectedSubCategoryId,
        manufacturerId: state.selectedManufacturerId,
        searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
      );

      state = state.copyWith(filteredProducts: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to filter products: $e',
      );
    }
  }

  void addToCart(PosProduct product) {
    final existingIndex = state.cartItems.indexWhere(
      (item) => item.productId == product.id,
    );

    List<BillItem> updatedCart;

    if (existingIndex >= 0) {
      final existingItem = state.cartItems[existingIndex];
      final newQuantity = existingItem.quantity + 1;
      final updatedItem = _createBillItem(
        product,
        newQuantity,
        existingItem.sellingPrice,
        state.selectedCustomer,
      );

      updatedCart = List.from(state.cartItems);
      updatedCart[existingIndex] = updatedItem;
    } else {
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

    final updatedCart = state.cartItems.map((item) {
      if (item.productId == productId) {
        final product = state.allProducts.firstWhere((p) => p.id == productId);
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
    state = state.copyWith(cartItems: [], clearCustomer: true);
  }

  void selectCustomer(Customer? customer) {
    print('\n=== SELECT CUSTOMER CALLED ===');
    print(
      'New Customer: ${customer?.name ?? "None"} (GST: ${customer?.gstNumber ?? "None"})',
    );
    print('Cart has ${state.cartItems.length} items');
    print('Company GST: ${state.companyGstNumber}');

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
      );
    } else {
      state = state.copyWith(
        selectedCustomer: customer,
        clearCustomer: customer == null,
      );
    }
  }

  void addToCartWithCustomPrice(PosProduct product, double customPrice) {
    final productWithCustomPrice = PosProduct(
      id: product.id,
      name: product.name,
      partNumber: product.partNumber,
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
    double cgstAmount = 0;
    double sgstAmount = 0;
    double igstAmount = 0;
    double taxAmount = 0;

    if (product.isTaxable) {
      // Use customerOverride if provided, otherwise use state.selectedCustomer
      final customer = customerOverride ?? state.selectedCustomer;

      // Default to CGST+SGST (intra-state)
      bool isInterState = false;

      // Debug: Print GST information
      print('DEBUG: Product: ${product.name}');
      print('DEBUG: Customer: ${customer?.name ?? "None"}');
      print('DEBUG: Customer GST: ${customer?.gstNumber ?? "None"}');
      print('DEBUG: Company GST: ${state.companyGstNumber ?? "None"}');
      print(
        'DEBUG: Product CGST: ${product.cgstRate}, SGST: ${product.sgstRate}, IGST: ${product.igstRate}',
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

        // If state codes are different, it's inter-state (IGST)
        if (customerStateCode != companyStateCode) {
          isInterState = true;
          print('DEBUG: Inter-state detected - Using IGST');
        } else {
          print('DEBUG: Intra-state detected - Using CGST+SGST');
        }
      }
      // If customer has no GST number, default to CGST+SGST (intra-state)

      if (isInterState) {
        // Inter-state: Apply IGST from product's GST rate
        igstRate = product.igstRate ?? 0.0;
        igstAmount = subtotal * igstRate / 100;
        taxAmount = igstAmount;
        print('DEBUG: Applying IGST - Rate: $igstRate%, Amount: ₹$igstAmount');
      } else {
        // Intra-state: Apply CGST + SGST from product's GST rates
        cgstRate = product.cgstRate ?? 0.0;
        sgstRate = product.sgstRate ?? 0.0;
        cgstAmount = subtotal * cgstRate / 100;
        sgstAmount = subtotal * sgstRate / 100;
        taxAmount = cgstAmount + sgstAmount;
        print(
          'DEBUG: Applying CGST+SGST - CGST: $cgstRate% (₹$cgstAmount), SGST: $sgstRate% (₹$sgstAmount), Total: ₹$taxAmount',
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
      utgstRate: 0,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      igstAmount: igstAmount,
      utgstAmount: 0,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
    );
  }

  // Checkout and create bill
  Future<String?> checkout() async {
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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create bill in database (this will also update stock batches)
      await _billRepository.createBill(bill, state.cartItems);

      // Clear cart after successful bill creation
      state = state.copyWith(cartItems: [], isLoading: false);

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
