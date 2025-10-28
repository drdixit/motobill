import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/database_provider.dart';
import '../model/gst_rate.dart';
import '../model/hsn_code.dart';
import '../repository/gst_rate_repository.dart';
import '../repository/hsn_code_repository.dart';

class GstRateState {
  final List<Map<String, dynamic>> gstRates;
  final bool isLoading;
  final String? error;

  GstRateState({this.gstRates = const [], this.isLoading = false, this.error});

  GstRateState copyWith({
    List<Map<String, dynamic>>? gstRates,
    bool? isLoading,
    String? error,
  }) {
    return GstRateState(
      gstRates: gstRates ?? this.gstRates,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class GstRateViewModel extends StateNotifier<GstRateState> {
  final GstRateRepository? _repository;
  final Ref? _ref;

  GstRateViewModel(this._repository, [this._ref]) : super(GstRateState()) {
    loadGstRates();
  }

  GstRateViewModel._loading()
    : _repository = null,
      _ref = null,
      super(GstRateState(isLoading: true));

  Future<void> loadGstRates() async {
    if (_repository == null) return;
    try {
      if (mounted) {
        state = state.copyWith(isLoading: true, error: null);
      }
      final gstRates = await _repository.getAllGstRates();
      if (!mounted) return;
      state = state.copyWith(gstRates: gstRates, isLoading: false);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString(), isLoading: false);
      }
    }
  }

  Future<int> addGstRate(GstRate gstRate) async {
    if (_repository == null) return -1;
    try {
      final id = await _repository.insertGstRate(gstRate);
      await loadGstRates();
      // Invalidate dependent providers if ref is still valid
      try {
        _ref?.invalidate(hsnCodesForGstProvider);
        _ref?.invalidate(gstRateByHsnProvider(gstRate.hsnCodeId));
      } catch (_) {}
      return id;
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateGstRate(GstRate gstRate) async {
    if (_repository == null) return;
    try {
      await _repository.updateGstRate(gstRate);
      await loadGstRates();
      try {
        _ref?.invalidate(hsnCodesForGstProvider);
        _ref?.invalidate(gstRateByHsnProvider(gstRate.hsnCodeId));
      } catch (_) {}
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteGstRate(int id) async {
    if (_repository == null) return;
    try {
      await _repository.deleteGstRate(id);
      await loadGstRates();
      try {
        // Try to invalidate the specific gst rate entry if we can determine its HSN
        final existing = await _repository.getGstRateById(id);
        _ref?.invalidate(hsnCodesForGstProvider);
        if (existing != null) {
          _ref?.invalidate(gstRateByHsnProvider(existing.hsnCodeId));
        }
      } catch (_) {}
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> toggleGstRateStatus(int id, bool isEnabled) async {
    if (_repository == null) return;
    try {
      await _repository.toggleGstRateStatus(id, isEnabled);
      await loadGstRates();
      try {
        final existing = await _repository.getGstRateById(id);
        _ref?.invalidate(hsnCodesForGstProvider);
        if (existing != null) {
          _ref?.invalidate(gstRateByHsnProvider(existing.hsnCodeId));
        }
      } catch (_) {}
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

// GST Rate Repository Provider
final gstRateRepositoryProvider = FutureProvider<GstRateRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return GstRateRepository(db);
});

// HSN Code Repository Provider for dropdown
final hsnCodeRepositoryForGstProvider = FutureProvider<HsnCodeRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return HsnCodeRepository(db);
});

// HSN Codes List Provider for dropdown
final hsnCodesForGstProvider = FutureProvider<List<HsnCode>>((ref) async {
  final repository = await ref.watch(hsnCodeRepositoryForGstProvider.future);
  return await repository.getAllHsnCodes();
});

// GST Rate ViewModel Provider
final gstRateViewModelProvider =
    StateNotifierProvider<GstRateViewModel, GstRateState>((ref) {
      final repositoryAsync = ref.watch(gstRateRepositoryProvider);

      return repositoryAsync.when(
        data: (repository) => GstRateViewModel(repository, ref),
        loading: () => GstRateViewModel._loading(),
        error: (error, stack) => GstRateViewModel._loading(),
      );
    });

// Provider to fetch GstRate by HSN id (used by UI lists)
final gstRateByHsnProvider = FutureProvider.family<GstRate?, int>((
  ref,
  hsnId,
) async {
  final repo = await ref.watch(gstRateRepositoryProvider.future);
  return await repo.getGstRateByHsnCodeId(hsnId);
});
