import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/database_provider.dart';
import '../model/manufacturer.dart';
import '../repository/manufacturer_repository.dart';
import 'pos_viewmodel.dart';
import 'product_viewmodel.dart';
import 'vehicle_viewmodel.dart';

// Manufacturer State
class ManufacturerState {
  final List<Manufacturer> manufacturers;
  final bool isLoading;
  final String? error;

  ManufacturerState({
    this.manufacturers = const [],
    this.isLoading = false,
    this.error,
  });

  ManufacturerState copyWith({
    List<Manufacturer>? manufacturers,
    bool? isLoading,
    String? error,
  }) {
    return ManufacturerState(
      manufacturers: manufacturers ?? this.manufacturers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Manufacturer ViewModel
class ManufacturerViewModel extends StateNotifier<ManufacturerState> {
  final ManufacturerRepository? _repository;
  final Ref? _ref;

  ManufacturerViewModel(this._repository, [this._ref])
    : super(ManufacturerState(isLoading: true)) {
    if (_repository != null) {
      loadManufacturers();
    }
  }

  ManufacturerViewModel._loading()
    : _repository = null,
      _ref = null,
      super(ManufacturerState(isLoading: true));

  Future<void> loadManufacturers() async {
    if (_repository == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final manufacturers = await _repository.getAllManufacturers();
      state = state.copyWith(manufacturers: manufacturers, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> createManufacturer(Manufacturer manufacturer) async {
    if (_repository == null) return;
    try {
      await _repository.createManufacturer(manufacturer);
      await loadManufacturers();
      _ref?.invalidate(posViewModelProvider);
      _ref?.invalidate(manufacturersForProductProvider);
      _ref?.invalidate(manufacturersListProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateManufacturer(Manufacturer manufacturer) async {
    if (_repository == null) return;
    try {
      await _repository.updateManufacturer(manufacturer);
      await loadManufacturers();
      _ref?.invalidate(posViewModelProvider);
      _ref?.invalidate(manufacturersForProductProvider);
      _ref?.invalidate(manufacturersListProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteManufacturer(int id) async {
    if (_repository == null) return;
    try {
      await _repository.softDeleteManufacturer(id);
      await loadManufacturers();
      _ref?.invalidate(posViewModelProvider);
      _ref?.invalidate(manufacturersForProductProvider);
      _ref?.invalidate(manufacturersListProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleManufacturerEnabled(int id, bool isEnabled) async {
    if (_repository == null) return;
    try {
      await _repository.toggleManufacturerEnabled(id, isEnabled);
      await loadManufacturers();
      _ref?.invalidate(posViewModelProvider);
      // Invalidate product and vehicle form providers to reflect changes immediately
      _ref?.invalidate(manufacturersForProductProvider);
      _ref?.invalidate(manufacturersListProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> searchManufacturers(String query) async {
    if (_repository == null) return;
    if (query.isEmpty) {
      await loadManufacturers();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final manufacturers = await _repository.searchManufacturers(query);
      state = state.copyWith(manufacturers: manufacturers, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

// Manufacturer Repository Provider
final manufacturerRepositoryProvider = FutureProvider<ManufacturerRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return ManufacturerRepository(db);
});

// Manufacturer Provider
final manufacturerProvider =
    StateNotifierProvider<ManufacturerViewModel, ManufacturerState>((ref) {
      final repositoryAsync = ref.watch(manufacturerRepositoryProvider);

      return repositoryAsync.when(
        data: (repository) => ManufacturerViewModel(repository, ref),
        loading: () => ManufacturerViewModel._loading(),
        error: (error, stack) => ManufacturerViewModel._loading(),
      );
    });
