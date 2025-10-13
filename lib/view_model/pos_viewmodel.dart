import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/pos_product.dart';
import '../model/bill.dart';
import '../model/customer.dart';
import '../model/main_category.dart';
import '../model/sub_category.dart';
import '../model/manufacturer.dart';
import '../repository/pos_repository.dart';
import '../repository/customer_repository.dart';
import '../core/providers/database_provider.dart';

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
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PosViewModel extends StateNotifier<PosState> {
  final PosRepository? _repository;
  final CustomerRepository? _customerRepository;

  PosViewModel(PosRepository repository, CustomerRepository customerRepository)
    : _repository = repository,
      _customerRepository = customerRepository,
      super(PosState()) {
    loadInitialData();
  }

  // Loading constructor for when repository isn't ready yet
  PosViewModel._loading()
    : _repository = null,
      _customerRepository = null,
      super(PosState(isLoading: true));

  Future<void> loadInitialData() async {
    if (_repository == null || _customerRepository == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final mainCategories = await _repository.getAllMainCategories();
      final manufacturers = await _repository.getAllManufacturers();
      final products = await _repository.getProductsForPos();
      final customers = await _customerRepository.getAllCustomers();

      state = state.copyWith(
        mainCategories: mainCategories,
        manufacturers: manufacturers,
        allProducts: products,
        filteredProducts: products,
        customers: customers,
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
      final updatedItem = _createBillItem(product, newQuantity);

      updatedCart = List.from(state.cartItems);
      updatedCart[existingIndex] = updatedItem;
    } else {
      final newItem = _createBillItem(product, 1);
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
        return _createBillItem(product, newQuantity, item.sellingPrice);
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
        return _createBillItem(product, item.quantity, newPrice);
      }
      return item;
    }).toList();

    state = state.copyWith(cartItems: updatedCart);
  }

  void updateCartItemTotal(int productId, double newTotal) {
    if (newTotal <= 0) return;

    final updatedCart = state.cartItems.map((item) {
      if (item.productId == productId) {
        final product = state.allProducts.firstWhere((p) => p.id == productId);

        double calculatedPrice;
        if (product.isTaxable) {
          calculatedPrice = newTotal / (item.quantity * 1.18);
        } else {
          calculatedPrice = newTotal / item.quantity;
        }

        return _createBillItem(product, item.quantity, calculatedPrice);
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
    state = state.copyWith(
      selectedCustomer: customer,
      clearCustomer: customer == null,
    );
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
    );
    addToCart(productWithCustomPrice);
  }

  BillItem _createBillItem(
    PosProduct product,
    int quantity, [
    double? customPrice,
  ]) {
    final price = customPrice ?? product.sellingPrice;
    final subtotal = price * quantity;

    // For now, using simple GST calculation (can be enhanced later)
    // Assuming 18% GST split as 9% CGST + 9% SGST for taxable items
    double cgstRate = 0;
    double sgstRate = 0;
    double cgstAmount = 0;
    double sgstAmount = 0;
    double taxAmount = 0;

    if (product.isTaxable) {
      cgstRate = 9.0;
      sgstRate = 9.0;
      cgstAmount = subtotal * cgstRate / 100;
      sgstAmount = subtotal * sgstRate / 100;
      taxAmount = cgstAmount + sgstAmount;
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
      igstRate: 0,
      utgstRate: 0,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      igstAmount: 0,
      utgstAmount: 0,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
    );
  }
}

// Provider that waits for repository and creates ViewModel
final posViewModelProvider = StateNotifierProvider<PosViewModel, PosState>((
  ref,
) {
  // Watch both repository futures and get the values synchronously
  // This will cause the provider to rebuild when repositories are ready
  final repository = ref.watch(posRepositoryFutureProvider).value;
  final customerRepository = ref.watch(customerRepositoryFutureProvider).value;

  if (repository == null || customerRepository == null) {
    // Return a ViewModel with loading state while repositories initialize
    return PosViewModel._loading();
  }

  return PosViewModel(repository, customerRepository);
});
