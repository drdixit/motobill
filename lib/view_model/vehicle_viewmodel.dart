import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/database_provider.dart';
import '../model/vehicle.dart';
import '../model/manufacturer.dart';
import '../model/vehicle_type.dart';
import '../model/fuel_type.dart';
import '../repository/vehicle_repository.dart';
import '../repository/manufacturer_repository.dart';

// Vehicle State
class VehicleState {
  final List<Vehicle> vehicles;
  final bool isLoading;
  final String? error;

  VehicleState({this.vehicles = const [], this.isLoading = false, this.error});

  VehicleState copyWith({
    List<Vehicle>? vehicles,
    bool? isLoading,
    String? error,
  }) {
    return VehicleState(
      vehicles: vehicles ?? this.vehicles,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Vehicle ViewModel
class VehicleViewModel extends StateNotifier<VehicleState> {
  final VehicleRepository? _repository;
  final Ref? _ref;

  VehicleViewModel(this._repository, [this._ref])
    : super(VehicleState(isLoading: true)) {
    if (_repository != null) {
      loadVehicles();
    }
  }

  VehicleViewModel._loading()
    : _repository = null,
      _ref = null,
      super(VehicleState(isLoading: true));

  Future<void> loadVehicles() async {
    if (_repository == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final vehicles = await _repository.getAllVehicles();
      state = state.copyWith(vehicles: vehicles, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> createVehicle(Vehicle vehicle) async {
    if (_repository == null) return;
    try {
      await _repository.createVehicle(vehicle);
      await loadVehicles();
      _ref?.invalidate(manufacturersListProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    if (_repository == null) return;
    try {
      await _repository.updateVehicle(vehicle);
      await loadVehicles();
      _ref?.invalidate(manufacturersListProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteVehicle(int id) async {
    if (_repository == null) return;
    try {
      await _repository.softDeleteVehicle(id);
      await loadVehicles();
      _ref?.invalidate(manufacturersListProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleVehicleEnabled(int id, bool isEnabled) async {
    if (_repository == null) return;
    try {
      await _repository.toggleVehicleEnabled(id, isEnabled);
      await loadVehicles();
      _ref?.invalidate(manufacturersListProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> searchVehicles(String query) async {
    if (_repository == null) return;
    if (query.isEmpty) {
      await loadVehicles();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final vehicles = await _repository.searchVehicles(query);
      state = state.copyWith(vehicles: vehicles, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

// Vehicle Repository Provider
final vehicleRepositoryProvider = FutureProvider<VehicleRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return VehicleRepository(db);
});

// Manufacturer Repository Provider (for dropdown)
final manufacturerRepositoryForVehicleProvider =
    FutureProvider<ManufacturerRepository>((ref) async {
      final db = await ref.watch(databaseProvider);
      return ManufacturerRepository(db);
    });

// Manufacturers List Provider (for dropdown)
final manufacturersListProvider = FutureProvider<List<Manufacturer>>((
  ref,
) async {
  final repository = await ref.watch(
    manufacturerRepositoryForVehicleProvider.future,
  );
  final manufacturers = await repository.getAllManufacturers();
  return manufacturers.where((m) => m.isEnabled && !m.isDeleted).toList();
});

// Vehicle Types List Provider (for dropdown)
final vehicleTypesListProvider = FutureProvider<List<VehicleType>>((ref) async {
  final repository = await ref.watch(vehicleRepositoryProvider.future);
  return await repository.getAllVehicleTypes();
});

// Fuel Types List Provider (for dropdown)
final fuelTypesListProvider = FutureProvider<List<FuelType>>((ref) async {
  final repository = await ref.watch(vehicleRepositoryProvider.future);
  return await repository.getAllFuelTypes();
});

// Vehicle Provider
final vehicleProvider = StateNotifierProvider<VehicleViewModel, VehicleState>((
  ref,
) {
  final repositoryAsync = ref.watch(vehicleRepositoryProvider);

  return repositoryAsync.when(
    data: (repository) => VehicleViewModel(repository, ref),
    loading: () => VehicleViewModel._loading(),
    error: (error, stack) => VehicleViewModel._loading(),
  );
});
