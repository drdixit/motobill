import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/pos_product.dart';
import '../model/bill.dart';
import '../model/main_category.dart';
import '../model/sub_category.dart';
import '../model/manufacturer.dart';
import '../repository/pos_repository.dart';
import '../core/providers/database_provider.dart';

final posRepositoryProvider = Provider<PosRepository>((ref) {
  throw UnimplementedError('Use posRepositoryFutureProvider instead');
});

final posRepositoryFutureProvider = FutureProvider<PosRepository>((ref) async {
  final db = await ref.watch(databaseProvider);
  return PosRepository(db);
});

class PosState {
  final List<PosProduct> allProducts;
  final List<PosProduct> filteredProducts;
  final List<BillItem> cartItems;
  final List<MainCategory> mainCategories;
  final List<SubCategory> subCategories;
  final List<Manufacturer> manufacturers;
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
  final PosRepository _repository;

  PosViewModel(this._repository) : super(PosState()) {
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final mainCategories = await _repository.getAllMainCategories();
      final manufacturers = await _repository.getAllManufacturers();
      final products = await _repository.getProductsForPos();

      state = state.copyWith(
        mainCategories: mainCategories,
        manufacturers: manufacturers,
        allProducts: products,
        filteredProducts: products,
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
    if (categoryId == state.selectedMainCategoryId) return;

    state = state.copyWith(
      selectedMainCategoryId: categoryId,
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
    state = state.copyWith(selectedSubCategoryId: subCategoryId);
    _applyFilters();
  }

  void selectManufacturer(int? manufacturerId) {
    state = state.copyWith(selectedManufacturerId: manufacturerId);
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
        return _createBillItem(product, newQuantity);
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
    state = state.copyWith(cartItems: []);
  }

  BillItem _createBillItem(PosProduct product, int quantity) {
    final subtotal = product.sellingPrice * quantity;

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
      sellingPrice: product.sellingPrice,
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

final posViewModelProvider = StateNotifierProvider<PosViewModel, PosState>((
  ref,
) {
  final repositoryAsync = ref.watch(posRepositoryFutureProvider);
  return repositoryAsync.when(
    data: (repository) => PosViewModel(repository),
    loading: () =>
        PosViewModel(throw UnimplementedError('Repository not ready')),
    error: (error, stack) => throw error,
  );
});
