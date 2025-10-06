import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/vendor.dart';
import '../repository/vendor_repository.dart';
import '../core/providers/database_provider.dart';

// State class
class VendorState {
  final List<Vendor> vendors;
  final bool isLoading;
  final String? error;

  VendorState({this.vendors = const [], this.isLoading = false, this.error});

  VendorState copyWith({
    List<Vendor>? vendors,
    bool? isLoading,
    String? error,
  }) {
    return VendorState(
      vendors: vendors ?? this.vendors,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ViewModel
class VendorViewModel extends StateNotifier<VendorState> {
  final VendorRepository? _repository;

  VendorViewModel(this._repository) : super(VendorState(isLoading: true)) {
    // Load vendors immediately if repository is available
    if (_repository != null) {
      loadVendors();
    }
  }

  // Factory for loading state
  VendorViewModel._loading()
    : _repository = null,
      super(VendorState(isLoading: true));

  Future<void> loadVendors() async {
    if (_repository == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final vendors = await _repository.getAllVendors();
      state = state.copyWith(vendors: vendors, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> createVendor(Vendor vendor) async {
    if (_repository == null) return;
    try {
      await _repository.createVendor(vendor);
      await loadVendors();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateVendor(Vendor vendor) async {
    if (_repository == null) return;
    try {
      await _repository.updateVendor(vendor);
      await loadVendors();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteVendor(int id) async {
    if (_repository == null) return;
    try {
      await _repository.softDeleteVendor(id);
      await loadVendors();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleVendorEnabled(int id, bool isEnabled) async {
    if (_repository == null) return;
    try {
      await _repository.toggleVendorEnabled(id, isEnabled);
      await loadVendors();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> searchVendors(String query) async {
    if (_repository == null) return;
    if (query.isEmpty) {
      await loadVendors();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final vendors = await _repository.searchVendors(query);
      state = state.copyWith(vendors: vendors, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

// Provider for VendorRepository (initialized with database)
final vendorRepositoryProvider = FutureProvider<VendorRepository>((ref) async {
  final db = await ref.watch(databaseProvider);
  return VendorRepository(db);
});

// StateNotifier provider for VendorViewModel - Main provider to use in UI
final vendorProvider = StateNotifierProvider<VendorViewModel, VendorState>((
  ref,
) {
  final repositoryAsync = ref.watch(vendorRepositoryProvider);

  return repositoryAsync.when(
    data: (repository) => VendorViewModel(repository),
    loading: () => VendorViewModel._loading(),
    error: (error, stack) => VendorViewModel._loading(),
  );
});
