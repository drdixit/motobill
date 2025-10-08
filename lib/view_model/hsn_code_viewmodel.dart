import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/database_provider.dart';
import '../model/hsn_code.dart';
import '../repository/hsn_code_repository.dart';

class HsnCodeState {
  final List<HsnCode> hsnCodes;
  final bool isLoading;
  final String? error;

  HsnCodeState({this.hsnCodes = const [], this.isLoading = false, this.error});

  HsnCodeState copyWith({
    List<HsnCode>? hsnCodes,
    bool? isLoading,
    String? error,
  }) {
    return HsnCodeState(
      hsnCodes: hsnCodes ?? this.hsnCodes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class HsnCodeViewModel extends StateNotifier<HsnCodeState> {
  final HsnCodeRepository? _repository;

  HsnCodeViewModel(this._repository) : super(HsnCodeState()) {
    loadHsnCodes();
  }

  HsnCodeViewModel._loading()
    : _repository = null,
      super(HsnCodeState(isLoading: true));

  Future<void> loadHsnCodes() async {
    if (_repository == null) return;
    try {
      state = state.copyWith(isLoading: true, error: null);
      final hsnCodes = await _repository.getAllHsnCodes();
      state = state.copyWith(hsnCodes: hsnCodes, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<int> addHsnCode(HsnCode hsnCode) async {
    if (_repository == null) return -1;
    try {
      final id = await _repository.insertHsnCode(hsnCode);
      await loadHsnCodes();
      return id;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateHsnCode(HsnCode hsnCode) async {
    if (_repository == null) return;
    try {
      await _repository.updateHsnCode(hsnCode);
      await loadHsnCodes();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteHsnCode(int id) async {
    if (_repository == null) return;
    try {
      await _repository.deleteHsnCode(id);
      await loadHsnCodes();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> toggleHsnCodeStatus(int id, bool isEnabled) async {
    if (_repository == null) return;
    try {
      await _repository.toggleHsnCodeStatus(id, isEnabled);
      await loadHsnCodes();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

// HSN Code Repository Provider
final hsnCodeRepositoryProvider = FutureProvider<HsnCodeRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return HsnCodeRepository(db);
});

// HSN Code ViewModel Provider
final hsnCodeViewModelProvider =
    StateNotifierProvider<HsnCodeViewModel, HsnCodeState>((ref) {
      final repositoryAsync = ref.watch(hsnCodeRepositoryProvider);

      return repositoryAsync.when(
        data: (repository) => HsnCodeViewModel(repository),
        loading: () => HsnCodeViewModel._loading(),
        error: (error, stack) => HsnCodeViewModel._loading(),
      );
    });
