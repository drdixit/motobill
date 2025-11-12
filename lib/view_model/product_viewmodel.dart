import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/database_provider.dart';
import '../model/product.dart';
import '../model/sub_category.dart';
import '../model/manufacturer.dart';
import '../repository/product_repository.dart';
import '../repository/sub_category_repository.dart';
import '../repository/manufacturer_repository.dart';
import 'pos_viewmodel.dart';

// Product State
class ProductState {
  final List<Product> products;
  final Map<int, ProductImage> productImages;
  final bool isLoading;
  final String? error;

  ProductState({
    this.products = const [],
    this.productImages = const {},
    this.isLoading = false,
    this.error,
  });

  ProductState copyWith({
    List<Product>? products,
    Map<int, ProductImage>? productImages,
    bool? isLoading,
    String? error,
  }) {
    return ProductState(
      products: products ?? this.products,
      productImages: productImages ?? this.productImages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Product ViewModel
class ProductViewModel extends StateNotifier<ProductState> {
  final ProductRepository? _repository;
  final Ref? _ref;

  ProductViewModel(this._repository, [this._ref])
    : super(ProductState(isLoading: true)) {
    if (_repository != null) {
      loadProducts();
    }
  }

  ProductViewModel._loading()
    : _repository = null,
      _ref = null,
      super(ProductState(isLoading: true));

  Future<void> loadProducts() async {
    if (_repository == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Load ALL products and images at once for instant access
      final products = await _repository.getAllProducts();
      final images = await _repository.getAllPrimaryProductImages();
      state = state.copyWith(
        products: products,
        productImages: images,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<int> addProduct(Product product) async {
    if (_repository == null) throw Exception('Repository not initialized');
    try {
      final id = await _repository.insertProduct(product);
      // Reload products and images
      await loadProducts();
      _ref?.invalidate(posViewModelProvider);
      return id;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    if (_repository == null) return;
    try {
      await _repository.updateProduct(product);
      await loadProducts();
      _ref?.invalidate(posViewModelProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteProduct(int id) async {
    if (_repository == null) return;
    try {
      await _repository.deleteProduct(id);
      await loadProducts();
      _ref?.invalidate(posViewModelProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> toggleProductStatus(int id, bool isEnabled) async {
    if (_repository == null) return;
    try {
      await _repository.toggleProductStatus(id, isEnabled);
      await loadProducts();
      _ref?.invalidate(posViewModelProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> addProductImage(
    int productId,
    String imagePath,
    bool isPrimary,
  ) async {
    if (_repository == null) return;
    try {
      final image = ProductImage(
        productId: productId,
        imagePath: imagePath,
        isPrimary: isPrimary,
      );
      await _repository.addProductImage(image);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> removeProductImage(int imageId) async {
    if (_repository == null) return;
    try {
      await _repository.removeProductImage(imageId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> setPrimaryImage(int productId, int imageId) async {
    if (_repository == null) return;
    try {
      await _repository.setPrimaryImage(productId, imageId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

// Product Repository Provider
final productRepositoryProvider = FutureProvider<ProductRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return ProductRepository(db);
});

// Sub Category Repository Provider (for dropdown)
final subCategoryRepositoryForProductProvider =
    FutureProvider<SubCategoryRepository>((ref) async {
      final db = await ref.watch(databaseProvider);
      return SubCategoryRepository(db);
    });

// Manufacturer Repository Provider (for dropdown)
final manufacturerRepositoryForProductProvider =
    FutureProvider<ManufacturerRepository>((ref) async {
      final db = await ref.watch(databaseProvider);
      return ManufacturerRepository(db);
    });

// Sub Categories List Provider (for dropdown)
final subCategoriesForProductProvider = FutureProvider<List<SubCategory>>((
  ref,
) async {
  final repository = await ref.watch(
    subCategoryRepositoryForProductProvider.future,
  );
  final subCategories = await repository.getAllSubCategories();
  return subCategories.where((sc) => sc.isEnabled && !sc.isDeleted).toList();
});

// Manufacturers List Provider (for dropdown)
final manufacturersForProductProvider = FutureProvider<List<Manufacturer>>((
  ref,
) async {
  final repository = await ref.watch(
    manufacturerRepositoryForProductProvider.future,
  );
  final manufacturers = await repository.getAllManufacturers();
  return manufacturers.where((m) => m.isEnabled && !m.isDeleted).toList();
});

// HSN Codes List Provider (for dropdown)
final hsnCodesListProvider = FutureProvider<List<HsnCode>>((ref) async {
  final repository = await ref.watch(productRepositoryProvider.future);
  return await repository.getAllHsnCodes();
});

// UQCs List Provider (for dropdown)
final uqcsListProvider = FutureProvider<List<Uqc>>((ref) async {
  final repository = await ref.watch(productRepositoryProvider.future);
  return await repository.getAllUqcs();
});

// Product Images Provider with aggressive caching
final productImagesProvider = FutureProvider.family
    .autoDispose<List<ProductImage>, int>((ref, productId) async {
      // Keep the provider alive to prevent disposal during fast scrolling
      ref.keepAlive();
      final repository = await ref.watch(productRepositoryProvider.future);
      return await repository.getProductImages(productId);
    });

// Product Provider
final productViewModelProvider =
    StateNotifierProvider<ProductViewModel, ProductState>((ref) {
      final repositoryAsync = ref.watch(productRepositoryProvider);

      return repositoryAsync.when(
        data: (repository) => ProductViewModel(repository, ref),
        loading: () => ProductViewModel._loading(),
        error: (error, stack) => ProductViewModel._loading(),
      );
    });
