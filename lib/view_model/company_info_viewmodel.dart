import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/database_provider.dart';
import '../model/company_info.dart';
import '../repository/company_info_repository.dart';

// Forward declaration - will be defined in bill_print_dialog.dart
// This is needed to invalidate the print provider when company info updates
final companyInfoForPrintProvider = FutureProvider<CompanyInfo?>((ref) async {
  final db = await ref.watch(databaseProvider);
  final repository = CompanyInfoRepository(db);
  return repository.getPrimaryCompanyInfo();
});

class CompanyInfoState {
  final CompanyInfo? companyInfo;
  final bool isLoading;
  final String? error;

  CompanyInfoState({this.companyInfo, this.isLoading = false, this.error});

  CompanyInfoState copyWith({
    CompanyInfo? companyInfo,
    bool? isLoading,
    String? error,
  }) {
    return CompanyInfoState(
      companyInfo: companyInfo ?? this.companyInfo,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CompanyInfoViewModel extends StateNotifier<CompanyInfoState> {
  final CompanyInfoRepository? _repository;
  final Ref? _ref;

  CompanyInfoViewModel(this._repository, [this._ref])
    : super(CompanyInfoState()) {
    loadPrimaryCompanyInfo();
  }

  CompanyInfoViewModel._loading()
    : _repository = null,
      _ref = null,
      super(CompanyInfoState(isLoading: true));

  Future<void> loadPrimaryCompanyInfo() async {
    if (_repository == null) return;
    try {
      state = state.copyWith(isLoading: true, error: null);
      final companyInfo = await _repository.getPrimaryCompanyInfo();
      state = state.copyWith(companyInfo: companyInfo, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> updateCompanyInfo(CompanyInfo companyInfo) async {
    if (_repository == null) return;
    try {
      await _repository.updateCompanyInfo(companyInfo);
      await loadPrimaryCompanyInfo();
      // Invalidate print provider to refresh company info in bills/receipts
      _ref?.invalidate(companyInfoForPrintProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

// Company Info Repository Provider
final companyInfoRepositoryProvider = FutureProvider<CompanyInfoRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  return CompanyInfoRepository(db);
});

// Company Info ViewModel Provider
final companyInfoViewModelProvider =
    StateNotifierProvider<CompanyInfoViewModel, CompanyInfoState>((ref) {
      final repositoryAsync = ref.watch(companyInfoRepositoryProvider);

      return repositoryAsync.when(
        data: (repository) => CompanyInfoViewModel(repository, ref),
        loading: () => CompanyInfoViewModel._loading(),
        error: (error, stack) => CompanyInfoViewModel._loading(),
      );
    });
