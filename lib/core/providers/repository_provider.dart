import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repository/todo_repository.dart';
import 'database_provider.dart';

// Future provider for TodoRepository
final todoRepositoryFutureProvider = FutureProvider<TodoRepository>((
  ref,
) async {
  final database = await ref.watch(databaseProvider);
  return TodoRepository(database);
});
