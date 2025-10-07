import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/database_provider.dart';
import '../model/sub_category.dart';
import '../model/main_category.dart';
import '../repository/sub_category_repository.dart';
import '../repository/main_category_repository.dart';

// Sub Category State
class SubCategoryState {
  final List<SubCategory> subCategories;
  final bool isLoading;
  final String? error;

  SubCategoryState({
    this.subCategories = const [],
    this.isLoading = false,
    this.error,
  });

  SubCategoryState copyWith({
    List<SubCategory>? subCategories,
    bool? isLoading,
    String? error,
  }) {
    return SubCategoryState(
      subCategories: subCategories ?? this.subCategories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Sub Category ViewModel
class SubCategoryViewModel extends StateNotifier<SubCategoryState> {
  final SubCategoryRepository? _repository;

  SubCategoryViewModel(this._repository)
    : super(SubCategoryState(isLoading: true)) {
    if (_repository != null) {
      loadSubCategories();
    }
  }

  SubCategoryViewModel._loading()
    : _repository = null,
      super(SubCategoryState(isLoading: true));

  Future<void> loadSubCategories() async {
    if (_repository == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final subCategories = await _repository.getAllSubCategories();
      state = state.copyWith(subCategories: subCategories, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> createSubCategory(SubCategory subCategory) async {
    if (_repository == null) return;
    try {
      await _repository.createSubCategory(subCategory);
      await loadSubCategories();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateSubCategory(SubCategory subCategory) async {
    if (_repository == null) return;
    try {
      await _repository.updateSubCategory(subCategory);
      await loadSubCategories();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteSubCategory(int id) async {
    if (_repository == null) return;
    try {
      await _repository.softDeleteSubCategory(id);
      await loadSubCategories();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleSubCategoryEnabled(int id, bool isEnabled) async {
    if (_repository == null) return;
    try {
      await _repository.toggleSubCategoryEnabled(id, isEnabled);
      await loadSubCategories();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// Sub Category Repository Provider
final subCategoryRepositoryProvider = FutureProvider<SubCategoryRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return SubCategoryRepository(db);
});

// Main Category Repository Provider (for dropdown)
final mainCategoryRepositoryProviderForDropdown =
    FutureProvider<MainCategoryRepository>((ref) async {
      final db = await ref.watch(databaseProvider);
      return MainCategoryRepository(db);
    });

// Main Categories List Provider (for dropdown)
final mainCategoriesListProvider = FutureProvider<List<MainCategory>>((
  ref,
) async {
  final repository = await ref.watch(
    mainCategoryRepositoryProviderForDropdown.future,
  );
  return await repository.getAllMainCategories();
});

// Sub Category Provider
final subCategoryProvider =
    StateNotifierProvider<SubCategoryViewModel, SubCategoryState>((ref) {
      final repositoryAsync = ref.watch(subCategoryRepositoryProvider);

      return repositoryAsync.when(
        data: (repository) => SubCategoryViewModel(repository),
        loading: () => SubCategoryViewModel._loading(),
        error: (error, stack) => SubCategoryViewModel._loading(),
      );
    });
