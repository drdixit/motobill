import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/database_provider.dart';
import '../repository/bank_repository.dart';
import '../model/bank.dart';

final bankRepositoryProvider = FutureProvider<BankRepository>((ref) async {
  final db = await ref.watch(databaseProvider);
  return BankRepository(db);
});

// Provider to get the bank for a given company id (nullable company id handled by caller)
final bankByCompanyProvider = FutureProvider.family<Bank?, int>((
  ref,
  companyId,
) async {
  final repo = await ref.watch(bankRepositoryProvider.future);
  return repo.getBankByCompanyId(companyId);
});
