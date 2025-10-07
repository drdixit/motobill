import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/main_category.dart';
import '../repository/main_category_repository.dart';
import '../core/providers/database_provider.dart';

// State class
class MainCategoryState {
  final List<MainCategory> categories;
  final bool isLoading;
  final String? error;

  MainCategoryState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  MainCategoryState copyWith({
    List<MainCategory>? categories,
    bool? isLoading,
    String? error,
  }) {
    return MainCategoryState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ViewModel
class MainCategoryViewModel extends StateNotifier<MainCategoryState> {
  final MainCategoryRepository? _repository;

  MainCategoryViewModel(this._repository)
    : super(MainCategoryState(isLoading: true)) {
    // Load categories immediately if repository is available
    if (_repository != null) {
      loadCategories();
    }
  }

  // Factory for loading state
  MainCategoryViewModel._loading()
    : _repository = null,
      super(MainCategoryState(isLoading: true));

  Future<void> loadCategories() async {
    if (_repository == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final categories = await _repository.getAllMainCategories();
      state = state.copyWith(categories: categories, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> createCategory(MainCategory category) async {
    if (_repository == null) return;
    try {
      await _repository.createMainCategory(category);
      await loadCategories();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateCategory(MainCategory category) async {
    if (_repository == null) return;
    try {
      await _repository.updateMainCategory(category);
      await loadCategories();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteCategory(int id) async {
    if (_repository == null) return;
    try {
      await _repository.softDeleteMainCategory(id);
      await loadCategories();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleCategoryEnabled(int id, bool isEnabled) async {
    if (_repository == null) return;
    try {
      await _repository.toggleMainCategoryEnabled(id, isEnabled);
      await loadCategories();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> searchCategories(String query) async {
    if (_repository == null) return;
    if (query.isEmpty) {
      await loadCategories();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final categories = await _repository.searchMainCategories(query);
      state = state.copyWith(categories: categories, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

// Provider for MainCategoryRepository (initialized with database)
final mainCategoryRepositoryProvider = FutureProvider<MainCategoryRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return MainCategoryRepository(db);
});

// StateNotifier provider for MainCategoryViewModel - Main provider to use in UI
final mainCategoryProvider =
    StateNotifierProvider<MainCategoryViewModel, MainCategoryState>((ref) {
      final repositoryAsync = ref.watch(mainCategoryRepositoryProvider);

      return repositoryAsync.when(
        data: (repository) => MainCategoryViewModel(repository),
        loading: () => MainCategoryViewModel._loading(),
        error: (error, stack) => MainCategoryViewModel._loading(),
      );
    });
