import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/database_provider.dart';
import '../model/manufacturer.dart';
import '../repository/manufacturer_repository.dart';

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

  ManufacturerViewModel(this._repository)
    : super(ManufacturerState(isLoading: true)) {
    if (_repository != null) {
      loadManufacturers();
    }
  }

  ManufacturerViewModel._loading()
    : _repository = null,
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
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleManufacturerEnabled(int id, bool isEnabled) async {
    if (_repository == null) return;
    try {
      await _repository.toggleManufacturerEnabled(id, isEnabled);
      await loadManufacturers();
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
        data: (repository) => ManufacturerViewModel(repository),
        loading: () => ManufacturerViewModel._loading(),
        error: (error, stack) => ManufacturerViewModel._loading(),
      );
    });
