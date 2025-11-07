import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/database_provider.dart';
import '../model/payment_summary.dart';
import '../repository/payment_repository.dart';

// Provider for receivables (customers who owe us money)
final receivablesProvider = FutureProvider<List<PaymentSummary>>((ref) async {
  final db = await ref.watch(databaseProvider);
  final repository = PaymentRepository(db);
  return await repository.getReceivables();
});

// Provider for payables (vendors we owe money to)
final payablesProvider = FutureProvider<List<PaymentSummary>>((ref) async {
  final db = await ref.watch(databaseProvider);
  final repository = PaymentRepository(db);
  return await repository.getPayables();
});

// Provider for customer refundables (what we owe customers for credit notes)
final customerRefundablesProvider = FutureProvider<List<PaymentSummary>>((
  ref,
) async {
  final db = await ref.watch(databaseProvider);
  final repository = PaymentRepository(db);
  return await repository.getCustomerRefundables();
});

// Provider for payment statistics
final paymentStatsProvider = FutureProvider<Map<String, double>>((ref) async {
  final db = await ref.watch(databaseProvider);
  final repository = PaymentRepository(db);
  return await repository.getPaymentStats();
});
