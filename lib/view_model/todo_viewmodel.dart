import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/todo.dart';
import '../repository/todo_repository.dart';
import '../core/providers/repository_provider.dart';

// State class for managing todo list
class TodoState {
  final List<Todo> todos;
  final bool isLoading;
  final String? error;

  const TodoState({this.todos = const [], this.isLoading = false, this.error});

  TodoState copyWith({List<Todo>? todos, bool? isLoading, String? error}) {
    return TodoState(
      todos: todos ?? this.todos,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ViewModel for managing todo operations
class TodoViewModel extends StateNotifier<TodoState> {
  final TodoRepository _repository;

  TodoViewModel(this._repository) : super(const TodoState()) {
    loadTodos();
  }

  // Load all todos
  Future<void> loadTodos() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final todos = await _repository.getAllTodos();
      state = state.copyWith(todos: todos, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Add a new todo
  Future<void> addTodo(String name, String description) async {
    try {
      final todo = Todo(name: name, description: description);
      await _repository.addTodo(todo);
      await loadTodos();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Update an existing todo
  Future<void> updateTodo(Todo todo) async {
    try {
      await _repository.updateTodo(todo);
      await loadTodos();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Delete a todo
  Future<void> deleteTodo(int id) async {
    try {
      await _repository.deleteTodo(id);
      await loadTodos();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// Temporary ViewModel for loading state
class _LoadingTodoViewModel extends TodoViewModel {
  _LoadingTodoViewModel() : super(_DummyRepository()) {
    state = const TodoState(isLoading: true);
  }
}

// Temporary ViewModel for error state
class _ErrorTodoViewModel extends TodoViewModel {
  _ErrorTodoViewModel(String error) : super(_DummyRepository()) {
    state = TodoState(error: error);
  }
}

// Dummy repository for temporary ViewModels
class _DummyRepository implements TodoRepository {
  @override
  Future<List<Todo>> getAllTodos() async => [];

  @override
  Future<Todo?> getTodoById(int id) async => null;

  @override
  Future<int> addTodo(Todo todo) async => 0;

  @override
  Future<void> updateTodo(Todo todo) async {}

  @override
  Future<void> deleteTodo(int id) async {}
}

// Provider for TodoViewModel that handles async initialization
final todoViewModelProvider = StateNotifierProvider<TodoViewModel, TodoState>((
  ref,
) {
  // Watch the repository future
  final repositoryAsync = ref.watch(todoRepositoryFutureProvider);

  // Handle different states
  return repositoryAsync.when(
    data: (repository) => TodoViewModel(repository),
    loading: () => _LoadingTodoViewModel(),
    error: (error, stack) => _ErrorTodoViewModel(error.toString()),
  );
});
