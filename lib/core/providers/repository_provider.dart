import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repository/todo_repository.dart';
import '../../repository/bill_repository.dart';
import 'database_provider.dart';

// Future provider for TodoRepository
final todoRepositoryFutureProvider = FutureProvider<TodoRepository>((
  ref,
) async {
  final database = await ref.watch(databaseProvider);
  return TodoRepository(database);
});

// Future provider for BillRepository
final billRepositoryFutureProvider = FutureProvider<BillRepository>((
  ref,
) async {
  final database = await ref.watch(databaseProvider);
  return BillRepository(database);
});
