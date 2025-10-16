import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/database_provider.dart';
import '../model/customer.dart';
import '../repository/customer_repository.dart';
import 'pos_viewmodel.dart';

/// State for customer list
class CustomerState {
  final List<Customer> customers;
  final bool isLoading;
  final String? error;

  CustomerState({
    this.customers = const [],
    this.isLoading = false,
    this.error,
  });

  CustomerState copyWith({
    List<Customer>? customers,
    bool? isLoading,
    String? error,
  }) {
    return CustomerState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// ViewModel for customer operations
class CustomerViewModel extends StateNotifier<CustomerState> {
  final CustomerRepository? _repository;
  final Ref? _ref;

  CustomerViewModel(this._repository, [this._ref])
    : super(CustomerState(isLoading: true)) {
    // Load customers immediately if repository is available
    if (_repository != null) {
      loadCustomers();
    }
  }

  // Factory for loading state
  CustomerViewModel._loading()
    : _repository = null,
      _ref = null,
      super(CustomerState(isLoading: true));

  /// Load all customers (including disabled ones for Masters screen)
  Future<void> loadCustomers() async {
    if (_repository == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final customers = await _repository.getAllCustomersIncludingDisabled();
      state = state.copyWith(customers: customers, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Create new customer
  Future<void> createCustomer(Customer customer) async {
    if (_repository == null) return;
    try {
      await _repository.createCustomer(customer);
      await loadCustomers(); // Refresh list
      // Invalidate POS to refresh customer list in POS screen
      _ref?.invalidate(posViewModelProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Update customer
  Future<void> updateCustomer(Customer customer) async {
    if (_repository == null) return;
    try {
      await _repository.updateCustomer(customer);
      await loadCustomers(); // Refresh list
      // Invalidate POS to refresh customer data in POS screen
      _ref?.invalidate(posViewModelProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Delete customer (soft delete)
  Future<void> deleteCustomer(int id) async {
    if (_repository == null) return;
    try {
      await _repository.softDeleteCustomer(id);
      await loadCustomers(); // Refresh list
      // Invalidate POS to refresh customer list in POS screen
      _ref?.invalidate(posViewModelProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Toggle customer enabled status
  Future<void> toggleCustomerEnabled(int id, bool isEnabled) async {
    if (_repository == null) return;
    try {
      await _repository.toggleCustomerEnabled(id, isEnabled);
      await loadCustomers(); // Refresh list - THIS WILL UPDATE THE UI IMMEDIATELY
      // Invalidate POS to refresh customer list in POS screen
      _ref?.invalidate(posViewModelProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Search customers
  Future<void> searchCustomers(String query) async {
    if (_repository == null) return;
    if (query.isEmpty) {
      await loadCustomers();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final customers = await _repository.searchCustomers(query);
      state = state.copyWith(customers: customers, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

/// Provider for CustomerRepository (initialized with database)
final customerRepositoryProvider = FutureProvider<CustomerRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return CustomerRepository(db);
});

/// StateNotifier provider for CustomerViewModel - Main provider to use in UI
final customerProvider =
    StateNotifierProvider<CustomerViewModel, CustomerState>((ref) {
      final repositoryAsync = ref.watch(customerRepositoryProvider);

      return repositoryAsync.when(
        data: (repository) => CustomerViewModel(repository, ref),
        loading: () => CustomerViewModel._loading(),
        error: (error, stack) => CustomerViewModel._loading(),
      );
    });
