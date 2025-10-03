import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../view_model/todo_viewmodel.dart';
import '../../model/todo.dart';
import 'add_todo_screen.dart';
import 'edit_todo_screen.dart';

class TodoListScreen extends ConsumerWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoState = ref.watch(todoViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(context, ref, todoState),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddTodo(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, TodoState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(todoViewModelProvider.notifier).loadTodos(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.todos.isEmpty) {
      return const Center(child: Text('No todos yet. Add one to get started!'));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(todoViewModelProvider.notifier).loadTodos(),
      child: ListView.builder(
        itemCount: state.todos.length,
        itemBuilder: (context, index) {
          final todo = state.todos[index];
          return _buildTodoItem(context, ref, todo);
        },
      ),
    );
  }

  Widget _buildTodoItem(BuildContext context, WidgetRef ref, Todo todo) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(
          todo.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(todo.description),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _navigateToEditTodo(context, todo),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: () => _confirmDelete(context, ref, todo),
            ),
          ],
        ),
        onTap: () => _navigateToEditTodo(context, todo),
      ),
    );
  }

  Future<void> _navigateToAddTodo(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTodoScreen()),
    );
  }

  Future<void> _navigateToEditTodo(BuildContext context, Todo todo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditTodoScreen(todo: todo)),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Todo todo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Todo'),
        content: Text('Are you sure you want to delete "${todo.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && todo.id != null) {
      ref.read(todoViewModelProvider.notifier).deleteTodo(todo.id!);
    }
  }
}
